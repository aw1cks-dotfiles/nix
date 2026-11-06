"""Fail-closed adapters for stock standalone Lix services (Python >= 3.9).

Accept exact nix-daemon[/ --daemon], nix daemon, and the installer's exact
wait4path shell wrapper; never accept arbitrary flags or arbitrary shell code.
Sources: lix-project/lix misc/systemd/nix-daemon.service.in (2.93.3), and
installed Lix 2.95.4 launchd plist/launchctl output. launchctl's diagnostic
format is not an API: unfamiliar execution fields or ambiguous blocks fail.
The loaded command selects the installation, independently of any user client.
validate() verifies its daemon and sibling frontend and returns the latter;
restart() requires the same service, executable identities, and Lix version.
"""
from __future__ import annotations

from collections import deque
import os
from pathlib import Path
import platform
import plistlib
import re
import shlex
import stat
import subprocess
from typing import Optional

LABEL = "org.nixos.nix-daemon"
PLIST = Path("/Library/LaunchDaemons/org.nixos.nix-daemon.plist")
UNIT = "nix-daemon.service"


def run(*args: str) -> str:
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout


def secure_file(path: Path) -> bytes:
    from daemon import check_secure
    check_secure(path)
    if not path.is_file():
        raise RuntimeError(f"Service definition is not a regular file: {path}")
    return path.read_bytes()


def check_definition_component(path: Path, metadata: os.stat_result) -> None:
    symlink = stat.S_ISLNK(metadata.st_mode)
    # Multi-user Linux stores use root:nixbld 1775. The sticky bit prevents
    # builders from replacing root-owned installation entries. This exception
    # is intentionally only the canonical store, never arbitrary sticky dirs.
    sticky_store = (
        path == Path("/nix/store")
        and stat.S_ISDIR(metadata.st_mode)
        and bool(metadata.st_mode & stat.S_ISVTX)
        and not metadata.st_mode & 0o002
    )
    if metadata.st_uid != 0 or (
        not symlink and metadata.st_mode & 0o022 and not sticky_store
    ):
        raise RuntimeError(f"Insecure systemd definition component: {path}")


def systemd_definition(path: Path) -> object:
    """Inspect linked units without weakening the no-symlink plist/config guard.

    systemd unit_file_resolve_symlink() preserves the source of links outside
    the unit lookup path in FragmentPath. Check every traversed component,
    including profile links and directory links, and snapshot their targets.
    Symlink permissions are not access controls; their owner and containing
    directory must be trusted instead.
    """
    if not path.is_absolute():
        raise RuntimeError("Expected an absolute systemd definition path")
    pending = deque(path.parts[1:])
    current = Path("/")
    links = []
    hops = 0
    root = current.lstat()
    if root.st_uid != 0 or root.st_mode & 0o022:
        raise RuntimeError("Insecure service definition root")
    while pending:
        part = pending.popleft()
        if part in ("", "."):
            continue
        if part == "..":
            current = current.parent
            continue
        candidate = current / part
        metadata = candidate.lstat()
        symlink = stat.S_ISLNK(metadata.st_mode)
        check_definition_component(candidate, metadata)
        if symlink:
            hops += 1
            if hops > 40:
                raise RuntimeError("Too many symlinks in systemd service definition")
            target = os.readlink(candidate)
            links.append((str(candidate), target))
            destination = Path(target)
            if destination.is_absolute():
                current = Path("/")
                parts = destination.parts[1:]
            else:
                parts = destination.parts
            pending.extendleft(reversed(parts))
        else:
            if pending and not stat.S_ISDIR(metadata.st_mode):
                raise RuntimeError(f"Non-directory service definition component: {candidate}")
            current = candidate
    if not current.is_file():
        raise RuntimeError(f"Service definition is not a regular file: {current}")
    return tuple(links), str(current), secure_file(current)


def environment(values: dict[str, str]) -> None:
    for key, value in values.items():
        if (key in {"HOME", "XDG_CONFIG_HOME", "XDG_CONFIG_DIRS", "ENV", "BASH_ENV"}
                or key.startswith(("LD_", "DYLD_"))
                or (key.startswith("NIX_") and key != "NIX_SSL_CERT_FILE")):
            raise RuntimeError(f"Unsupported daemon configuration environment: {key}")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) or "\n" in value:
            raise RuntimeError("Ambiguous service environment")


def assignments(text: str) -> dict[str, str]:
    try:
        words = shlex.split(text)
    except ValueError as error:
        raise RuntimeError("Unparseable systemd environment") from error
    result: dict[str, str] = {}
    for word in words:
        key, sep, value = word.partition("=")
        if not sep or key in result or "\\" in word:
            raise RuntimeError("Ambiguous systemd environment")
        result[key] = value
    environment(result)
    return result


def secure_executable(executable: str) -> object:
    from daemon import check_secure
    source = Path(executable)
    if not re.fullmatch(r"/nix/store/[A-Za-z0-9+._=-]+/bin/(nix|nix-daemon)", executable):
        raise RuntimeError("Expected a canonical store-installed Lix executable")
    path = source.resolve(strict=True)
    if source.parent.resolve(strict=True) != source.parent or source.parent.parent not in path.parents:
        raise RuntimeError("Daemon executable resolves outside its canonical Lix installation")
    # A stock nix-daemon may be a symlink to nix in the same installation.
    # Check both names and every directory that controls their replacement.
    check_definition_component(source, source.lstat())
    for parent in path.parents:
        check_definition_component(parent, parent.lstat())
    check_secure(path)
    metadata = path.stat()
    if not stat.S_ISREG(metadata.st_mode) or not os.access(path, os.X_OK):
        raise RuntimeError(f"Daemon executable is not an executable regular file: {path}")
    return str(path), metadata.st_dev, metadata.st_ino, metadata.st_size, metadata.st_mtime_ns


def daemon_argv(executable: str, argv: list[str], shell: bool = False) -> str:
    if not isinstance(executable, str):
        raise RuntimeError("Invalid daemon executable")
    if shell and executable == "/bin/sh" and len(argv) == 3 and argv[:2] == ["/bin/sh", "-c"]:
        match = re.fullmatch(
            r"/bin/wait4path /nix/store && exec (/nix/store/[A-Za-z0-9+._=-]+/bin/nix-daemon)",
            argv[2],
        )
        if match:
            executable = match[1]
            argv = [executable]
    if not re.fullmatch(r"/nix/store/[A-Za-z0-9+._=-]+/bin/(nix|nix-daemon)", executable):
        raise RuntimeError("Expected a canonical store-installed Lix daemon")
    if Path(executable).name == "nix-daemon":
        allowed = ([executable], [executable, "--daemon"], ["nix-daemon", "--daemon"])
    else:
        allowed = ([executable, "daemon"],)
    if argv not in allowed:
        raise RuntimeError("Unsupported Lix daemon command; flags and custom wrappers require an adapter")
    return executable


def lix_version(executable: str) -> tuple[str, str]:
    text = run(executable, "--version").strip()
    first = text.splitlines()[0] if text else ""
    match = re.fullmatch(r"(?:nix|nix-daemon) \(Lix, like Nix\) ([0-9][^\s]*)", first)
    if not match:
        raise RuntimeError(f"Daemon installation executable is not recognized Lix: {executable}")
    return text, match[1]


class Service:
    def __init__(self) -> None:
        self.version = ""
        self._validated: Optional[object] = None

    def snapshot(self) -> tuple[str, object]:
        raise NotImplementedError

    def validate(self) -> str:
        executable, policy = self.snapshot()
        nix = str(Path(executable).with_name("nix"))
        daemon_identity = secure_executable(executable)
        if executable == nix:
            nix_identity = daemon_identity
            version, daemon_version = lix_version(executable)
            client_version = daemon_version
        else:
            nix_identity = secure_executable(nix)
            _, daemon_version = lix_version(executable)
            version, client_version = lix_version(nix)
        if daemon_version != client_version:
            raise RuntimeError("Daemon and parser versions differ within the Lix installation")
        snapshot = policy, executable, daemon_identity, nix_identity, version, daemon_version
        if self._validated is not None and snapshot != self._validated:
            raise RuntimeError("Daemon service changed after validation")
        self._validated = snapshot
        self.version = version
        return nix

    def restart(self) -> None:
        if self._validated is None:
            raise RuntimeError("Daemon service has not been validated")
        self.validate()
        self.restart_validated()

    def restart_validated(self) -> None:
        raise NotImplementedError


# Require every property, including empty ones. Older managers missing any
# safety property need an explicit adapter, not a guessed default.
EMPTY_PROPERTIES = (
    "EnvironmentFiles", "PassEnvironment", "UnsetEnvironment", "PAMName",
    "RootDirectory", "RootImage", "ExecCondition", "ExecStartPre", "ExecStartPost",
    "ExecStop", "ExecStopPost", "BindPaths", "BindReadOnlyPaths",
    "TemporaryFileSystem", "InaccessiblePaths", "ReadOnlyPaths", "ReadWritePaths",
    "ExtensionImages", "ExtensionDirectories", "MountImages",
)
PROPERTIES = (
    "LoadState", "NeedDaemonReload", "FragmentPath", "DropInPaths", "ExecStart",
    "Environment", "User", "Group", "DynamicUser", "WorkingDirectory", "ProtectHome", "PrivateUsers",
) + EMPTY_PROPERTIES


class SystemdService(Service):
    def snapshot(self) -> tuple[str, object]:
        output = run("systemctl", "show", UNIT, "--all", "--no-pager",
                     "--property=" + ",".join(PROPERTIES))
        props: dict[str, str] = {}
        for line in output.splitlines():
            key, sep, value = line.partition("=")
            if not sep or key in props or key not in PROPERTIES:
                raise RuntimeError("Ambiguous systemd service properties")
            props[key] = value
        if set(props) != set(PROPERTIES):
            raise RuntimeError("Missing systemd safety properties")
        if props["LoadState"] != "loaded" or props["NeedDaemonReload"] != "no":
            raise RuntimeError("Daemon definition is unloaded or differs from disk; review and reload it first")
        if (any(props[key] for key in EMPTY_PROPERTIES)
                or props["User"] not in ("", "root", "0")
                or props["Group"] not in ("", "root", "0")
                or props["DynamicUser"] != "no"
                or props["ProtectHome"] != "no" or props["PrivateUsers"] != "no"
                or props["WorkingDirectory"] not in ("", "/")):
            raise RuntimeError("Unsupported systemd execution or environment settings")
        assignments(props["Environment"])
        manager = assignments(run("systemctl", "show-environment"))
        # ExecStart's runtime timestamps/PID/status are not service policy.
        match = re.fullmatch(
            r"\{ path=([^ ;\\]+) ; argv\[\]=([^;{}\\]+) ; ignore_errors=no ; "
            r"start_time=[^;{}]* ; stop_time=[^;{}]* ; pid=[0-9]+ ; code=[^;{}]* ; status=[^;{}]* \}",
            props["ExecStart"],
        )
        if not match:
            raise RuntimeError("Unrecognized systemd ExecStart")
        executable, arguments = match.groups()
        argv = arguments.strip().split(" ")
        daemon = daemon_argv(executable, argv)
        del props["ExecStart"]
        paths = [props["FragmentPath"]] + props["DropInPaths"].split()
        if any(not path.startswith("/") or "\\" in path for path in paths):
            raise RuntimeError("Ambiguous systemd definition paths")
        files = tuple((path, systemd_definition(Path(path))) for path in paths)
        return daemon, (props, (executable, tuple(argv)), manager, files)

    def restart_validated(self) -> None:
        run("systemctl", "restart", UNIT)


def launch_fields(text: str, header: str) -> dict[str, object]:
    """Read only a balanced, uniquely-keyed top-level launchctl print object.

    Nested bodies remain opaque until a relevant block is parsed separately.
    No substring search: nested metadata cannot masquerade as policy fields.
    """
    lines = text.splitlines()
    if not lines or lines[0] != header + " = {" or lines[-1] != "}":
        raise RuntimeError("Unrecognized launchctl print structure; review the service with an operator-specific adapter")
    fields: dict[str, object] = {}
    index = 1
    while index < len(lines) - 1:
        line = lines[index].strip()
        index += 1
        if not line:
            continue
        key, sep, value = line.partition(" = ")
        if not sep or not key or key in fields:
            raise RuntimeError("Ambiguous launchctl print field; review the service with an operator-specific adapter")
        if value == "{":
            body = []
            depth = 1
            while index < len(lines) - 1:
                entry = lines[index].strip()
                index += 1
                if entry.endswith(" = {"):
                    depth += 1
                elif entry == "}":
                    depth -= 1
                    if depth == 0:
                        break
                body.append(entry)
            if depth:
                raise RuntimeError("Unbalanced launchctl print block; review the service with an operator-specific adapter")
            fields[key] = body
        else:
            if "{" in value or "}" in value:
                raise RuntimeError("Unrecognized launchctl print value; review the service with an operator-specific adapter")
            fields[key] = value
    return fields


def launch_environment(block: object) -> dict[str, str]:
    if not isinstance(block, list):
        raise RuntimeError("Missing launchctl environment block")
    result: dict[str, str] = {}
    for line in block:
        key, sep, value = line.partition(" => ")
        if not sep or key in result:
            raise RuntimeError("Ambiguous launchctl environment")
        result[key] = value
    environment(result)
    return result


# Observed metadata in stock macOS 26 launchctl print. Unknown fields are not
# assumed harmless: especially execution context, inherited config, or wrappers.
LAUNCH_METADATA = set("""active count|path|type|state|program|arguments|default environment|
 environment|inherited environment|domain|minimum runtime|exit timeout|runs|pid|
 immediate reason|forks|execs|initialized|trampolined|started suspended|
 proxy started suspended|checked allocations|checked allocations reason|
 checked allocations flags|last exit code|last terminating signal|
 resource coalition|jetsam coalition|spawn type|jetsam priority|
 jetsam memory limit (active)|jetsam memory limit (inactive)|jetsamproperties category|
 jetsam thread limit|cpumon|resource limits|properties""".replace("\n", "").split("|"))
LAUNCH_METADATA = {key.strip() for key in LAUNCH_METADATA}
PLIST_KEYS = {
    "Label", "Program", "ProgramArguments", "EnvironmentVariables", "KeepAlive",
    "RunAtLoad", "LowPriorityIO", "ProcessType", "SoftResourceLimits",
    "HardResourceLimits", "StandardErrorPath", "StandardOutPath",
}


class LaunchdService(Service):
    def snapshot(self) -> tuple[str, object]:
        data = secure_file(PLIST)
        try:
            definition = plistlib.loads(data)
        except (ValueError, plistlib.InvalidFileException) as error:
            raise RuntimeError("Invalid daemon plist") from error
        if (not isinstance(definition, dict) or set(definition) - PLIST_KEYS
                or definition.get("Label") != LABEL):
            raise RuntimeError("Unsupported launchd plist settings")
        argv = definition.get("ProgramArguments")
        if not isinstance(argv, list) or not argv or not all(isinstance(arg, str) for arg in argv):
            raise RuntimeError("Missing launchd daemon arguments")
        executable = definition.get("Program", argv[0])
        daemon = daemon_argv(executable, argv, shell=True)
        disk_env = definition.get("EnvironmentVariables", {})
        if not isinstance(disk_env, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in disk_env.items()):
            raise RuntimeError("Invalid plist environment")
        environment(disk_env)
        loaded = launch_fields(run("launchctl", "print", "system/" + LABEL), "system/" + LABEL)
        if set(loaded) - LAUNCH_METADATA:
            raise RuntimeError("Unrecognized launchctl service settings; review the service with an operator-specific adapter")
        if (loaded.get("path") != str(PLIST) or loaded.get("type") != "LaunchDaemon"
                or loaded.get("domain") != "system" or loaded.get("program") != executable
                or loaded.get("arguments") != argv):
            raise RuntimeError("Loaded launchd command differs from plist")
        defaults = launch_environment(loaded.get("default environment"))
        actual = launch_environment(loaded.get("environment"))
        # These are injected by launchd, not plist configuration.
        actual.pop("OSLogRateLimit", None)
        if actual.pop("XPC_SERVICE_NAME", None) != LABEL or actual != disk_env:
            raise RuntimeError("Loaded launchd environment differs from plist")
        inherited = launch_environment(loaded.get("inherited environment", []))
        domain = launch_fields(run("launchctl", "print", "system"), "system")
        if domain.get("type") != "system":
            raise RuntimeError("Unrecognized launchctl system domain; review the service with an operator-specific adapter")
        domain_env = {}
        for key, value in domain.items():
            if "environment" in key:
                if key not in {"environment", "default environment", "inherited environment"}:
                    raise RuntimeError("Unrecognized launchd domain environment")
                domain_env[key] = launch_environment(value)
        return daemon, (data, executable, tuple(argv), disk_env, defaults, inherited, domain_env)

    def restart_validated(self) -> None:
        run("launchctl", "kickstart", "-k", "system/" + LABEL)


def detect_service() -> Service:
    system = platform.system()
    if system == "Linux":
        return SystemdService()
    if system == "Darwin":
        return LaunchdService()
    raise RuntimeError("Only standalone systemd Linux and launchd macOS services are supported")
