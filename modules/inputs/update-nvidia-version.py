import argparse
import json
import socket
import subprocess
import sys
from pathlib import Path


NVIDIA_HOSTS = json.loads(r"""@nvidiaHostsJson@""")
NV_VERSION_PATH = Path("/sys/module/nvidia/version")


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def local_short_hostname() -> str:
    return socket.gethostname().split(".")[0]


def detect_nvidia_version() -> str:
    if not NV_VERSION_PATH.is_file():
        die(
            "NVIDIA kernel module version file not readable: "
            f"{NV_VERSION_PATH}\n"
            "Pass VERSION explicitly: update-nvidia-version <VERSION>"
        )
    return NV_VERSION_PATH.read_text().strip()


def prefetch_nvidia_hash(version: str, arch: str) -> str:
    url = (
        f"https://download.nvidia.com/XFree86/Linux-{arch}"
        f"/{version}/NVIDIA-Linux-{arch}-{version}.run"
    )
    log(f"Prefetching: {url}")
    result = subprocess.run(
        [
            "nix",
            "store",
            "prefetch-file",
            "--hash-type",
            "sha256",
            "--json",
            url,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        die(f"nix store prefetch-file failed:\n{result.stderr.strip()}")
    data = json.loads(result.stdout)
    hash_value = data.get("hash")
    if not hash_value:
        die(f"failed to resolve NVIDIA installer hash for URL: {url}")
    return hash_value


def git_toplevel() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(result.stdout.strip())


def render_pin_file(version: str, sha256: str) -> str:
    return json.dumps({"version": version, "sha256": sha256}, indent=2) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Update NVIDIA driver version and hash in a host pin file."
    )
    parser.add_argument("version", nargs="?", default=None)
    parser.add_argument("target", nargs="?", default=None)
    args = parser.parse_args()

    if not NVIDIA_HOSTS:
        die("No NVIDIA-enabled home configurations are defined.")

    hostname = args.target or local_short_hostname()
    target = NVIDIA_HOSTS.get(hostname)
    if not target:
        available = ", ".join(
            f"{host} ({meta['attr']})" for host, meta in sorted(NVIDIA_HOSTS.items())
        )
        die(f'No NVIDIA-enabled host "{hostname}". Available: {available}')

    is_remote = hostname != local_short_hostname()
    if is_remote and args.version is None:
        die(f'VERSION is required when targeting non-local host "{hostname}"')

    version = args.version or detect_nvidia_version()
    sha256 = prefetch_nvidia_hash(version, target["arch"])

    pin_path = git_toplevel() / target["pinFile"]
    if not pin_path.is_file():
        die(f"Pin file not found: {target['pinFile']}")

    new_contents = render_pin_file(version, sha256)
    old_contents = pin_path.read_text()

    if old_contents == new_contents:
        log(f"NVIDIA pin file already up to date: {version}")
        return

    pin_path.write_text(new_contents)
    log(f"Updated {target['pinFile']} to version={version} sha256={sha256}")


if __name__ == "__main__":
    main()
