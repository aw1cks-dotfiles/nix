"""Privileged, fail-closed cache policy installation; importing has no side effects."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto
import os
from pathlib import Path
import pwd
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from typing import Callable

BEGIN = "# BEGIN aw1cks cache provisioning"
END = "# END aw1cks cache provisioning"
HEADER = "# Managed by aw1cks cache bootstrap v1"


def check_secure(path: Path) -> None:
    metadata = path.lstat()
    if stat.S_ISLNK(metadata.st_mode):
        raise RuntimeError(f"Refusing symlink: {path}")
    if metadata.st_uid != 0:
        raise RuntimeError(f"Not root-owned: {path}")
    if metadata.st_mode & 0o022:
        raise RuntimeError(f"Group/other writable: {path}")


def fragment_values(policy: str) -> dict[str, set[str]]:
    lines = policy.removesuffix("\n").split("\n")
    if (len(lines) != 4 or lines[0] != HEADER
            or not re.fullmatch(r"# Inventory sha256: [a-f0-9]{64}", lines[1])):
        raise RuntimeError("Unrecognized or unsafe fragment; review it manually.")
    result = {}
    for line, setting, pattern in (
        (lines[2], "substituters", r"https://[A-Za-z0-9./_?=&%:+~-]+"),
        (lines[3], "trusted-public-keys", r"[A-Za-z0-9._-]+:[A-Za-z0-9+/]{43}="),
    ):
        fields = line.split()
        if fields[:2] != ["extra-" + setting, "="] or any(
                not re.fullmatch(pattern, token) for token in fields[2:]):
            raise RuntimeError("Unrecognized or unsafe fragment; review it manually.")
        result[setting] = set(fields[2:])
    return result


def main_candidate(original: str, dest: Path) -> tuple[str, bool]:
    state = 0
    seen = False
    ended = False
    for line in original.splitlines():
        if line == BEGIN:
            if seen or state:
                raise RuntimeError("Conflicting/partial include block; no files changed.")
            seen = True
            state = 1
        elif line == END:
            if state != 2:
                raise RuntimeError("Conflicting/partial include block; no files changed.")
            state = 0
            ended = True
        elif state == 1 and line == f"include {dest}":
            state = 2
        elif (state or "aw1cks-caches.conf" in line
              or "aw1cks cache provisioning" in line
              or (ended and line.strip() and not line.lstrip().startswith("#"))):
            raise RuntimeError("Conflicting/partial include block; no files changed.")
    if state:
        raise RuntimeError("Conflicting/partial include block; no files changed.")
    if seen:
        return original, False
    separator = "" if not original or original.endswith("\n") else "\n"
    return original + separator + f"{BEGIN}\ninclude {dest}\n{END}\n", True


def validation_config(candidate: str, directory: Path, dest: Path, staged: Path) -> str:
    lines = []
    for line in candidate.splitlines():
        fields = line.split()
        if fields and fields[0] in ("include", "!include"):
            if len(fields) < 2 or (len(fields) > 2 and not fields[2].startswith("#")):
                raise RuntimeError("Malformed admin include in main configuration.")
            path = Path(fields[1])
            path = staged if path == dest else path if path.is_absolute() else directory / path
            lines.append(f"{fields[0]} {path}")
        else:
            lines.append(line)
    return "\n".join(lines) + "\n"


def parse_candidate(check: Path, nix: str) -> dict[str, set[str]]:
    env = dict(os.environ)
    env.pop("NIX_USER_CONF_FILES", None)
    env.pop("NIX_REMOTE", None)
    env.update(NIX_CONFIG="", NIX_CONF_DIR=str(check))
    result = subprocess.run(
        [nix, "--extra-experimental-features", "nix-command", "--offline", "config", "show"],
        env=env, text=True, capture_output=True,
    )
    if result.returncode or re.search(r"warning:|error:", result.stderr, re.IGNORECASE):
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
        raise RuntimeError("Candidate configuration does not parse without warnings.")
    effective = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1] == "=":
            effective[fields[0]] = set(fields[2:])
    return effective


@dataclass(frozen=True)
class Candidate:
    main: str
    enrollment: bool
    expected: dict[str, set[str]]
    retired: dict[str, set[str]]

    @property
    def removes_trust(self) -> bool:
        return any(self.retired.values())

    def validate_effective(self, effective: dict[str, set[str]]) -> None:
        if effective.get("require-sigs") != {"true"}:
            raise RuntimeError("Signature verification is disabled; fix daemon policy before provisioning.")
        for setting, tokens in self.expected.items():
            if not tokens <= effective.get(setting, set()):
                raise RuntimeError(f"Candidate lost expected {setting} entries.")
            if self.retired[setting] & effective.get(setting, set()):
                raise RuntimeError(f"Retired {setting} entry also exists outside the owned fragment.")


def policy_candidate(original: str, previous: str | None, policy: str, dest: Path) -> Candidate:
    """Decide enrollment and trust changes without touching installed files."""
    if re.search(r"^\s*#.*(NixOS|nix-darwin|Determinate|generated from.*nix.settings)", original, re.I | re.M):
        raise RuntimeError("Main configuration has a declarative/external owner; refusing to edit it.")
    expected = fragment_values(policy)
    old = fragment_values(previous) if previous is not None else {key: set() for key in expected}
    retired = {key: old[key] - expected[key] for key in expected}
    main, enrollment = main_candidate(original, dest)
    return Candidate(main, enrollment, expected, retired)


class Publication(Enum):
    PREPARED = auto()
    FRAGMENT_PENDING = auto()
    FRAGMENT_INSTALLED = auto()
    MAIN_PENDING = auto()
    MAIN_INSTALLED = auto()
    COMMITTED = auto()


def published_files(state: Publication, txn: Path | None) -> tuple[bool, bool]:
    """Reconcile a signal between a successful rename and its state update."""
    if txn is None:
        return False, False
    fragment = state in (
        Publication.FRAGMENT_INSTALLED, Publication.MAIN_PENDING,
        Publication.MAIN_INSTALLED, Publication.COMMITTED,
    ) or (state == Publication.FRAGMENT_PENDING and not (txn / "fragment.new").exists())
    main = state == Publication.MAIN_INSTALLED or (
        state in (Publication.MAIN_PENDING, Publication.COMMITTED) and not (txn / "main.new").exists())
    return fragment, main


def _write_private(path: Path, content: bytes) -> None:
    with path.open("xb") as stream:
        os.chmod(path, 0o600)
        stream.write(content)


def _backup(source: Path, destination: Path, content: bytes) -> None:
    _write_private(destination, content)
    shutil.copystat(source, destination)
    os.chmod(destination, 0o600)


def _restore(backup: Path, destination: Path, metadata: os.stat_result) -> None:
    staged = backup.with_suffix(".rollback")
    shutil.copy2(backup, staged)
    os.chown(staged, metadata.st_uid, metadata.st_gid)
    os.chmod(staged, stat.S_IMODE(metadata.st_mode))
    os.utime(staged, ns=(metadata.st_atime_ns, metadata.st_mtime_ns))
    os.replace(staged, destination)


def _identity(metadata: os.stat_result) -> tuple[int, ...]:
    return (metadata.st_dev, metadata.st_ino, metadata.st_uid, metadata.st_gid,
            metadata.st_mode, metadata.st_size, metadata.st_mtime_ns, metadata.st_ctime_ns)


def transaction(directory: Path, policy: str, nix: str,
                restart: Callable[[], None], wait: Callable[[], None]) -> None:
    directory = directory.absolute()
    check_secure(directory)
    if not directory.is_dir():
        raise RuntimeError("Configuration directory is not a directory.")
    lock = directory / ".aw1cks-caches.lock"
    try:
        lock.mkdir(mode=0o700)
    except FileExistsError:
        raise RuntimeError(f"Another sync holds {lock} (or a prior run was interrupted); inspect before removing it.") from None
    txn = None
    state = Publication.PREPARED
    candidate = None
    previous_handlers = {}
    main = directory / "nix.conf"
    dest = directory / "aw1cks-caches.conf"
    old = None
    old_metadata = None

    def interrupted(signum: int, frame: object) -> None:
        raise RuntimeError(f"Interrupted by signal {signum}.")

    try:
        for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
            previous_handlers[signum] = signal.signal(signum, interrupted)
        check_secure(main)
        if not main.is_file():
            raise RuntimeError(f"Missing regular {main}; install Lix first.")
        metadata = main.stat()
        original = main.read_bytes()
        text = original.decode("utf-8")
        if os.path.lexists(dest):
            check_secure(dest)
            if not dest.is_file():
                raise RuntimeError("Fragment is not a regular file.")
            old_metadata = dest.stat()
            old = dest.read_bytes()
        candidate = policy_candidate(text, old.decode("utf-8") if old is not None else None, policy, dest)
        txn = Path(tempfile.mkdtemp(prefix=".aw1cks-caches.", dir=directory))
        os.chmod(txn, 0o700)
        _backup(main, txn / "main.before", original)
        if old is not None:
            _backup(dest, txn / "fragment.before", old)
        staged = txn / "fragment.new"
        _write_private(staged, policy.encode("utf-8"))
        staged_main = txn / "main.new"
        _write_private(staged_main, candidate.main.encode("utf-8"))
        shutil.copystat(main, staged_main)
        os.chown(staged_main, metadata.st_uid, metadata.st_gid)
        os.chmod(staged_main, stat.S_IMODE(metadata.st_mode))
        check = txn / "check"
        check.mkdir(mode=0o700)
        _write_private(check / "nix.conf", validation_config(candidate.main, directory, dest, staged).encode("utf-8"))
        candidate.validate_effective(parse_candidate(check, nix))
        check_secure(main)
        if _identity(main.stat()) != _identity(metadata) or main.read_bytes() != original:
            raise RuntimeError("Main config changed during validation; retry.")
        if old is not None:
            check_secure(dest)
            if _identity(dest.stat()) != _identity(old_metadata) or dest.read_bytes() != old:
                raise RuntimeError("Fragment changed during validation; retry.")
        elif os.path.lexists(dest):
            raise RuntimeError("Fragment appeared during validation; retry.")
        os.chown(staged, 0, -1)
        os.chmod(staged, 0o644)
        state = Publication.FRAGMENT_PENDING
        os.replace(staged, dest)
        state = Publication.FRAGMENT_INSTALLED
        if candidate.enrollment:
            state = Publication.MAIN_PENDING
            os.replace(staged_main, main)
            state = Publication.MAIN_INSTALLED
        restart()
        wait()
        state = Publication.COMMITTED
        print("cache-provision: file installed, include validated, daemon restarted and reachable.")
        print("cache-provision: this does NOT verify cache coverage or ordinary-user substitution.")
    finally:
        # Ignore further termination requests while restoring policy and recording
        # the recovery location. Reconcile rename consumption, not just Python state.
        for signum in previous_handlers:
            signal.signal(signum, signal.SIG_IGN)
        fragment_installed, main_installed = published_files(state, txn)
        committed = state == Publication.COMMITTED
        try:
            if not committed and fragment_installed:
                if candidate.removes_trust:
                    print(f"cache-provision: FAILED after a key/cache removal. New policy retained; refusing to restore retired trust. Backups: {txn}", file=sys.stderr)
                else:
                    try:
                        if main_installed:
                            _restore(txn / "main.before", main, metadata)
                        if old is None:
                            dest.unlink()
                        else:
                            _restore(txn / "fragment.before", dest, old_metadata)
                    except (OSError, RuntimeError):
                        print(f"cache-provision: rollback FAILED; restore root-only backups at {txn}", file=sys.stderr)
                    else:
                        try:
                            restart()
                            wait()
                        except (OSError, RuntimeError, subprocess.SubprocessError):
                            print("cache-provision: old files restored, but daemon recovery failed; administrator action required.", file=sys.stderr)
            elif not committed and candidate is not None and candidate.removes_trust:
                print("cache-provision: FAILED before replacement. Old policy remains; new policy not installed.", file=sys.stderr)
            if txn is not None:
                shutil.rmtree(txn / "check", ignore_errors=True)
                # Staging files must not expose administrative configuration in
                # retained backups; only installed configuration is world-readable.
                for child in txn.iterdir():
                    if child.is_file() and not child.is_symlink():
                        child.chmod(0o600)
                if fragment_installed:
                    print(f"cache-provision: root-only transaction/backups: {txn}", file=sys.stderr)
                else:
                    shutil.rmtree(txn)
        finally:
            try:
                lock.rmdir()
            finally:
                for signum, handler in previous_handlers.items():
                    signal.signal(signum, handler)


def wait_for_daemon(nix: str) -> None:
    env = dict(os.environ, NIX_CONFIG="", NIX_USER_CONF_FILES="/dev/null", NIX_REMOTE="daemon")
    for attempt in range(5):
        result = subprocess.run([nix, "--extra-experimental-features", "nix-command", "--store", "daemon", "store", "ping"], env=env, stdout=subprocess.DEVNULL)
        if result.returncode == 0:
            return
        if attempt < 4:
            time.sleep(1)
    raise RuntimeError("Daemon did not become reachable.")


def main(argv=None) -> int:
    try:
        args = sys.argv[1:] if argv is None else argv
        if os.geteuid() != 0:
            raise RuntimeError("Root is required.")
        if args:
            raise RuntimeError("Expected no arguments; daemon identity comes from the service.")
        if any(Path(path).exists() for path in ("/run/current-system/nixos-version", "/run/current-system/darwin-version")):
            raise RuntimeError("NixOS/nix-darwin owns this daemon. Use its declarative configuration.")
        if os.environ.get("NIX_CONF_DIR", "/etc/nix") != "/etc/nix":
            raise RuntimeError("Nonstandard daemon config requires an adapter.")
        if os.path.lexists("/etc/nix/conf.d/dendritic-caches.conf"):
            raise RuntimeError("Legacy dendritic-caches.conf exists; inspect its includes and migrate it first (see docs/cache-bootstrap.md).")
        for name in ("NIX_CONF_DIR", "NIX_REMOTE", "NIX_CONFIG", "NIX_USER_CONF_FILES", "XDG_CONFIG_HOME", "XDG_CONFIG_DIRS"):
            os.environ.pop(name, None)
        os.environ["HOME"] = pwd.getpwuid(0).pw_dir
        # Isolated Python omits the script directory. Add only our installation,
        # never an inherited search path or the current working directory.
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import services
        service = services.detect_service()
        nix = service.validate()
        print(f"cache-provision: daemon installation: {service.version}")
        transaction(Path("/etc/nix"), sys.stdin.read(), nix, service.restart, lambda: wait_for_daemon(nix))
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError, UnicodeError) as error:
        print(f"cache-provision: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
