{
  inputs,
  lib,
  config,
  ...
}:
let
  # Extract the short hostname from a homeConfigurations attr name
  # e.g. "alex.wicks@ixmbldevk05.mavensecurities.com" -> "ixmbldevk05"
  extractHost =
    name:
    let
      afterAt = builtins.elemAt (builtins.split "@" name) 2;
    in
    builtins.head (builtins.split "\\." afterAt);

  # Build a map of nvidia-enabled homeConfigurations: { "shorthost" = "user@host.domain"; }
  # Keyed by short hostname for easy lookup from the script.
  nvidiaHosts = lib.filterAttrs (_: _: true) (
    lib.concatMapAttrs (
      name: hm:
      let
        cfg = hm.config.targets.genericLinux.gpu.nvidia or { };
      in
      if cfg.enable or false then { ${extractHost name} = name; } else { }
    ) config.flake.homeConfigurations
  );
in
{
  flake-file.inputs.home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  # Expose home-manager CLI as the default app
  perSystem =
    {
      system,
      pkgs,
      inputs',
      ...
    }:
    let
      nimaPkg = inputs.nix-manipulator.packages.${system}.default;
      nimaPython = nimaPkg.pythonModule.withPackages (_: nimaPkg.requiredPythonModules ++ [ nimaPkg ]);
      nvidiaUpdateScript = pkgs.writeShellApplication {
        name = "update-nvidia-version";
        runtimeInputs = [
          pkgs.git
          pkgs.nix
        ];
        text = ''
          exec ${nimaPython}/bin/python3 ${updateScript} "$@"
        '';
      };
      updateScript = pkgs.writeText "update-nvidia-version.py" ''
        """Update NVIDIA driver version and hash in a host's Nix configuration."""

        import argparse
        import json
        import socket
        import subprocess
        import sys
        from pathlib import Path

        from nix_manipulator import parse, parse_file
        from nix_manipulator.cli.manipulations import set_value

        _HOSTS_JSON = r"""
        ${builtins.toJSON nvidiaHosts}
        """
        NVIDIA_HOSTS: dict[str, str] = json.loads(
            _HOSTS_JSON,
        )
        SYS_ARCH = "${pkgs.stdenv.hostPlatform.uname.processor}"
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
                    "NVIDIA kernel module version file not "
                    f"readable: {NV_VERSION_PATH}\n"
                    "       Pass VERSION explicitly: "
                    "update-nvidia-version <VERSION>"
                )
            return NV_VERSION_PATH.read_text().strip()


        def prefetch_nvidia_hash(version: str) -> str:
            url = (
                f"https://download.nvidia.com/XFree86/Linux-{SYS_ARCH}"
                f"/{version}/NVIDIA-Linux-{SYS_ARCH}-{version}.run"
            )
            log(f"Prefetching: {url}")
            cmd = [
                "nix", "store", "prefetch-file",
                "--hash-type", "sha256", "--json", url,
            ]
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0:
                die(
                    "nix store prefetch-file failed:\n"
                    f"{result.stderr.strip()}"
                )
            data = json.loads(result.stdout)
            h = data.get("hash")
            if not h:
                die(
                    "failed to resolve NVIDIA installer "
                    f"hash for URL: {url}"
                )
            return h


        def git_toplevel() -> Path:
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True,
                text=True,
                check=True,
            )
            return Path(result.stdout.strip())


        def main() -> None:
            parser = argparse.ArgumentParser(
                description=(
                    "Update NVIDIA driver version and hash "
                    "in Nix configuration."
                ),
            )
            parser.add_argument(
                "version",
                nargs="?",
                default=None,
                help=(
                    "NVIDIA driver version "
                    "(default: read from "
                    "/sys/module/nvidia/version)"
                ),
            )
            parser.add_argument(
                "target",
                nargs="?",
                default=None,
                help="Short hostname (default: local hostname)",
            )
            args = parser.parse_args()

            if not NVIDIA_HOSTS:
                die(
                    "no homeConfigurations with "
                    "targets.genericLinux.gpu.nvidia"
                    ".enable = true"
                )

            hostname = args.target or local_short_hostname()
            hm_attr = NVIDIA_HOSTS.get(hostname)
            if not hm_attr:
                available = ", ".join(
                    f"{h} ({a})"
                    for h, a in NVIDIA_HOSTS.items()
                )
                die(
                    "no nvidia-enabled homeConfigurations "
                    f"entry for host \"{hostname}\"\n"
                    "       Available nvidia hosts: "
                    f"{available}"
                )

            log(f"Resolved: {hm_attr} (host: {hostname})")

            mod_rel = Path("modules/hosts") / hostname / "configuration.nix"
            mod_path = git_toplevel() / mod_rel
            log(f"Host module path: {mod_rel}")

            is_remote = hostname != local_short_hostname()
            if is_remote and args.version is None:
                die(
                    "VERSION is required when targeting "
                    f"non-local host \"{hostname}\"\n"
                    "       Usage: update-nvidia-version "
                    f"<VERSION> {hostname}"
                )

            if not mod_path.is_file():
                die(f"host module file not found: {mod_rel}")

            nv_version = args.version or detect_nvidia_version()
            log(f"Target NVIDIA version: {nv_version}")

            nv_hash = prefetch_nvidia_hash(nv_version)

            original = mod_path.read_text()
            source = parse_file(mod_path)

            updated = set_value(source, "@nvidiaDriverVersion", f'"{nv_version}"')
            source = parse(updated)
            updated = set_value(source, "@nvidiaDriverHash", f'"{nv_hash}"')

            if updated.rstrip("\n") == original.rstrip("\n"):
                log(f"Nix configuration already up to date: {nv_version}")
                return

            mod_path.write_text(updated)
            log(
                f"Updated nvidiaDriverVersion={nv_version}"
                f" and nvidiaDriverHash={nv_hash}"
            )


        if __name__ == "__main__":
            main()
      '';
    in
    {
      apps.default = {
        type = "app";
        program = "${inputs.home-manager.packages.${system}.home-manager}/bin/home-manager";
      };

      packages.update-nvidia-version = nvidiaUpdateScript;
    };
}
