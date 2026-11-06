#!/usr/bin/env python3
"""Source-level Lix cache bootstrap; Python 3.9+ and no third-party modules."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
RENDERER = HERE.parent.parent / "shared/_render-cache-conf.nix"
ROOT_PATH = "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CLIENT_POLICY = (
    "extra-experimental-features = nix-command flakes\n"
    "accept-flake-config = false\nrequire-sigs = true\n"
)


def client_env(config: str = "", *, daemon: bool = False) -> dict[str, str]:
    env = dict(os.environ)
    env.pop("NIX_CONF_DIR", None)
    env.pop("NIX_REMOTE", None)
    env.update(NIX_CONFIG=config, NIX_USER_CONF_FILES="/dev/null")
    if daemon:
        env["NIX_REMOTE"] = "daemon"
    return env


def installed_lix() -> str:
    if os.environ.get("NIX_CONF_DIR", "/etc/nix") != "/etc/nix":
        raise RuntimeError("Nonstandard NIX_CONF_DIR requires an explicit service adapter.")
    nix = shutil.which("nix")
    if nix is None:
        raise RuntimeError("Install Lix first; no bootstrap tools were fetched.")
    nix = os.path.abspath(nix)
    version = subprocess.run([nix, "--version"], env=client_env(), check=True,
                             text=True, capture_output=True).stdout
    if "lix" not in version.lower():
        raise RuntimeError("This bootstrap supports Lix, not upstream/Determinate Nix.")
    return nix


def render(nix: str, mode: str = "extra") -> str:
    if mode not in ("extra", "replace", "official"):
        raise RuntimeError("Unknown render mode.")
    return subprocess.run(
        [nix, "--extra-experimental-features", "nix-command", "--option",
         "allow-import-from-derivation", "false", "--store", "dummy://", "eval",
         "--offline", "--raw", "--file", str(RENDERER), "--apply",
         f'f: f {{ mode = "{mode}"; }}'],
        env=client_env(), check=True, text=True, capture_output=True,
    ).stdout


def local_target(value: str) -> tuple[Path, str]:
    # Split the final delimiter: a literal # is allowed in the filesystem path.
    directory, delimiter, name = value.rpartition("#")
    if not delimiter or not re.fullmatch(r"[A-Za-z0-9._@-]+", name):
        raise RuntimeError("Target must be a local directory plus #NAME.")
    path = Path(directory)
    if not directory or not path.is_dir() or not (path / "flake.nix").is_file():
        raise RuntimeError("Target must be a reviewed local flake checkout.")
    # Let Lix resolve .#NAME from the checkout, preserving Git's tracked-file
    # boundary and avoiding hand-built URLs for spaces or reserved characters.
    return path.resolve(), f".#{name}"


def approve(yes: bool) -> None:
    if yes:
        return
    try:
        with open("/dev/tty", "w", encoding="utf-8") as output, open(
                "/dev/tty", "r", encoding="utf-8") as terminal:
            output.write("Continue? [y/N] ")
            output.flush()
            answer = terminal.readline().strip()
    except OSError as error:
        raise RuntimeError("No terminal; review first, then use --yes.") from error
    if answer not in ("y", "Y", "yes"):
        raise RuntimeError("Cancelled.")


def privileged(args: list[str], *, config: str | None = None, policy: str | None = None,
               cwd: Path | None = None) -> None:
    # No sudo -E, caller NIX_CONFIG, Python environment, or writable profile PATH.
    command = ["/usr/bin/env", "-i", "HOME=" + ("/var/root" if platform.system() == "Darwin" else "/root"),
               "PATH=" + ROOT_PATH]
    if config is not None:
        command += ["NIX_CONFIG=" + config, "NIX_USER_CONF_FILES=/dev/null", "NIX_REMOTE=daemon"]
    command += args
    if os.geteuid() != 0:
        command = ["sudo", "--"] + command
    subprocess.run(command, input=policy, text=True, check=True, cwd=cwd)


def privileged_python(script: Path, *, policy: str) -> None:
    # Resolve virtualenv/profile links before elevation. Isolation controls
    # imports, not trust in the interpreter; use an administrator-owned binary.
    interpreter = Path(sys.executable).resolve(strict=True)
    metadata = interpreter.stat()
    if (metadata.st_uid != 0 or metadata.st_mode & 0o022
            or not stat.S_ISREG(metadata.st_mode) or not os.access(interpreter, os.X_OK)):
        raise RuntimeError("Privileged provisioning requires an administrator-owned Python interpreter.")
    # -I alone still executes interpreter-relative .pth and sitecustomize hooks.
    privileged([str(interpreter), "-I", "-S", str(script)], policy=policy)


def ping(nix: str) -> None:
    subprocess.run([nix, "--extra-experimental-features", "nix-command", "--store",
                    "daemon", "store", "ping"], env=client_env(daemon=True), check=True)


def sync_caches(nix: str, yes: bool) -> None:
    version = subprocess.run([nix, "--version"], env=client_env(), check=True,
                             text=True, capture_output=True).stdout.splitlines()[0]
    print(f"Client: {version}", file=sys.stderr)
    policy = render(nix)
    print("Standalone daemon policy: /etc/nix/aw1cks-caches.conf\n" + policy, file=sys.stderr)
    print("This restarts the daemon and can interrupt concurrent builds.", file=sys.stderr)
    approve(yes)
    privileged_python(HERE / "daemon.py", policy=policy)
    ping(nix)
    print("Daemon responds. Use probe with an absent signed store path to test substitution.")


def system_bootstrap(nix: str, owner: str, checkout: Path, target: str, yes: bool, recovery: bool) -> None:
    system = platform.system()
    if owner == "nixos":
        if system != "Linux" or not Path("/run/current-system/nixos-version").exists():
            raise RuntimeError("nixos requires a NixOS host/installer.")
    elif system != "Darwin":
        raise RuntimeError("darwin requires macOS.")
    policy = render(nix, "official" if recovery else "extra")
    config = CLIENT_POLICY + "fallback = false\n" + policy
    print(f"First activation ({owner}): {checkout} {target}\n{policy}", file=sys.stderr)
    if recovery:
        print("Recovery uses only the official cache; missing substitutes may require builds.", file=sys.stderr)
    print("Missing substitutes can cause local builds, including the kernel; cache coverage is not guaranteed.", file=sys.stderr)
    approve(yes)
    if owner == "nixos":
        rebuild = shutil.which("nixos-rebuild")
        if rebuild is None:
            raise RuntimeError("nixos-rebuild is not installed.")
        args = [os.path.abspath(rebuild), "switch", "--flake", target]
    else:
        args = [nix, "--store", "daemon", "run", "--no-write-lock-file", ".#darwin",
                "--", "switch", "--flake", target]
    privileged(args, config=config, cwd=checkout)
    print("Activation completed. Re-run check-caches without temporary overrides; no bootstrap file was installed.")


def check_caches(nix: str) -> None:
    expected = render(nix)
    fragment = Path("/etc/nix/aw1cks-caches.conf")
    if fragment.exists():
        if expected.rstrip("\n") != fragment.read_text().rstrip("\n"):
            raise RuntimeError("Standalone fragment differs from this inventory; run sync-caches.")
        if "include /etc/nix/aw1cks-caches.conf" not in Path("/etc/nix/nix.conf").read_text().splitlines():
            raise RuntimeError("Standalone fragment exists but its include is missing.")
        print("Standalone fragment matches the inventory.")
    else:
        print("No standalone fragment (expected for declaratively managed hosts).")
    for setting in ("substituters", "trusted-public-keys"):
        subprocess.run([nix, "--extra-experimental-features", "nix-command", "config", "show", setting],
                       env=client_env(), check=True)
    ping(nix)
    print("Above settings are a client view, NOT a daemon-policy dump; substitution is unverified.")


def probe(nix: str, path: str) -> None:
    if os.geteuid() == 0:
        raise RuntimeError("Run probe as the ordinary HM/build user, not root.")
    if not re.fullmatch(r"/nix/store/[0-9a-z]{32}-[A-Za-z0-9+._?=-]+", path) or path.endswith(".drv"):
        raise RuntimeError("probe accepts one complete output store path, not a derivation.")
    if os.path.lexists(path):
        raise RuntimeError("Path already exists; choose an absent fixture. Nothing was removed.")
    nix_store = str(Path(nix).parent / "nix-store")
    if not os.access(nix_store, os.X_OK):
        raise RuntimeError("The installed Lix is missing nix-store.")
    subprocess.run([nix_store, "--realise", path, "--option", "max-jobs", "0", "--option", "builders", ""],
                   env=client_env(CLIENT_POLICY, daemon=True), check=True)
    print("Daemon substituted the requested output path; derivations are never accepted.")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--yes", action="store_true", help="Approve the displayed policy non-interactively.")
    result.add_argument("--recovery", action="store_true", help="Use official-only system bootstrap policy.")
    commands = result.add_subparsers(dest="command", required=True)
    bootstrap = commands.add_parser("bootstrap", help="First activation with explicit configuration ownership.")
    bootstrap.add_argument("owner", choices=("nixos", "darwin", "standalone-hm"))
    bootstrap.add_argument("target", metavar="LOCAL-FLAKE#NAME")
    commands.add_parser("sync-caches", help="Provision/update standalone daemon policy.")
    commands.add_parser("check-caches", help="Check file drift and daemon liveness, not substitution.")
    commands.add_parser("probe", help="Request an absent signed output through the daemon.").add_argument("store_path")
    commands.add_parser("render", help="Render policy without flake evaluation or realization.").add_argument(
        "mode", nargs="?", choices=("extra", "replace", "official"), default="extra")
    return result


def main(argv: list[str] | None = None) -> int:
    if sys.version_info < (3, 9):
        print("bootstrap-cache: Python 3.9 or newer is required; no interpreter was fetched.", file=sys.stderr)
        return 1
    args = parser().parse_args(argv)
    try:
        nix = installed_lix()
        if args.command == "render":
            print(render(nix, args.mode), end="")
        elif args.command == "sync-caches":
            sync_caches(nix, args.yes)
        elif args.command == "check-caches":
            check_caches(nix)
        elif args.command == "probe":
            probe(nix, args.store_path)
        else:
            checkout, target = local_target(args.target)
            if args.owner == "standalone-hm":
                if os.geteuid() == 0:
                    raise RuntimeError("Run HM bootstrap as the target user; only provisioning uses sudo.")
                sync_caches(nix, args.yes)
                subprocess.run([nix, "--store", "daemon", "run", "--no-write-lock-file", ".#home-manager",
                                "--", "switch", "--flake", target],
                               env=client_env(CLIENT_POLICY, daemon=True), check=True, cwd=checkout)
            else:
                system_bootstrap(nix, args.owner, checkout, target, args.yes, args.recovery)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"bootstrap-cache: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr, file=sys.stderr, end="")
        return 1
    except KeyboardInterrupt:
        print("bootstrap-cache: Interrupted.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
