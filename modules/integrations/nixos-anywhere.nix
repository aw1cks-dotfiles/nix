{ lib, inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    lib.mkIf (inputs ? nixos-anywhere && builtins.hasAttr system inputs.nixos-anywhere.packages) (
      let
        nixosAnywhere = inputs.nixos-anywhere.packages.${system}.default;
        installHost = pkgs.writeShellApplication {
          name = "install-host";
          runtimeInputs = [
            nixosAnywhere
            pkgs.git
          ];
          text = ''
            if [ "$#" -lt 2 ]; then
              echo "usage: install-host <hostname> <target-host> [nixos-anywhere args...]" >&2
              exit 1
            fi

            host_name="$1"
            target_host="$2"
            shift 2

            repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            host_dir="$repo_root/hosts/$host_name"

            if [ ! -d "$host_dir" ]; then
              echo "host directory not found: $host_dir" >&2
              exit 1
            fi

            exec nixos-anywhere \
              --flake "$repo_root#$host_name" \
              --extra-files "$host_dir" \
              "$@" \
              "$target_host"
          '';
          meta.description = "Run nixos-anywhere with the repo's host bootstrap files";
        };
        installHostVmTest = pkgs.writeShellApplication {
          name = "install-host-vm-test";
          runtimeInputs = [
            nixosAnywhere
            pkgs.git
          ];
          text = ''
            if [ "$#" -lt 1 ]; then
              echo "usage: install-host-vm-test <hostname> [nixos-anywhere args...]" >&2
              exit 1
            fi

            host_name="$1"
            shift

            repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            host_dir="$repo_root/hosts/$host_name"

            if [ ! -d "$host_dir" ]; then
              echo "host directory not found: $host_dir" >&2
              exit 1
            fi

            exec nixos-anywhere \
              --flake "$repo_root#$host_name" \
              --vm-test \
              "$@"
          '';
          meta.description = "Run nixos-anywhere --vm-test against a repo host";
        };
      in
      {
        packages = {
          nixos-anywhere = nixosAnywhere;
          install-host = installHost;
          install-host-vm-test = installHostVmTest;
        };

        apps.nixos-anywhere = {
          type = "app";
          program = "${nixosAnywhere}/bin/nixos-anywhere";
          meta.description = "Run nixos-anywhere from this flake's pinned input";
        };

        apps.install-host = {
          type = "app";
          program = "${installHost}/bin/install-host";
          meta.description = "Install a repo host through nixos-anywhere with bootstrap files";
        };

        apps.install-host-vm-test = {
          type = "app";
          program = "${installHostVmTest}/bin/install-host-vm-test";
          meta.description = "Run the repo host provisioning path through nixos-anywhere --vm-test";
        };
      }
    );
}
