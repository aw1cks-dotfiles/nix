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
            pkgs.openssh
            pkgs.sshpass
          ];
          text = ''
            set -euo pipefail

            if [ "$#" -lt 2 ]; then
              echo "usage: install-host <hostname> <target-host> [nixos-anywhere args...]" >&2
              exit 1
            fi

            host_name="$1"
            target_host="$2"
            shift 2

            repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            host_dir="$repo_root/hosts/$host_name"
            bootstrap_script="$host_dir/bootstrap-pre-kexec.sh"

            if [ ! -d "$host_dir" ]; then
              echo "host directory not found: $host_dir" >&2
              exit 1
            fi

            nixos_anywhere_args=("$@")
            use_sshpass=0
            ssh_args=()

            for ((arg_index = 0; arg_index < ''${#nixos_anywhere_args[@]}; arg_index++)); do
              arg="''${nixos_anywhere_args[$arg_index]}"
              case "$arg" in
                -i)
                  arg_index=$((arg_index + 1))
                  if [ "$arg_index" -ge "''${#nixos_anywhere_args[@]}" ]; then
                    echo "install-host: -i requires a value" >&2
                    exit 1
                  fi
                  ssh_args+=("-i" "''${nixos_anywhere_args[$arg_index]}")
                  ;;
                -p|--ssh-port)
                  arg_index=$((arg_index + 1))
                  if [ "$arg_index" -ge "''${#nixos_anywhere_args[@]}" ]; then
                    echo "install-host: $arg requires a value" >&2
                    exit 1
                  fi
                  ssh_args+=("-p" "''${nixos_anywhere_args[$arg_index]}")
                  ;;
                --ssh-option)
                  arg_index=$((arg_index + 1))
                  if [ "$arg_index" -ge "''${#nixos_anywhere_args[@]}" ]; then
                    echo "install-host: --ssh-option requires a value" >&2
                    exit 1
                  fi
                  ssh_args+=("-o" "''${nixos_anywhere_args[$arg_index]}")
                  ;;
                --env-password)
                  use_sshpass=1
                  ;;
              esac
            done

            if [ -f "$bootstrap_script" ]; then
              echo "install-host: running host-local bootstrap pre-kexec hook $bootstrap_script" >&2

              ssh_command=(ssh)
              if [ "$use_sshpass" -eq 1 ]; then
                ssh_command=(sshpass -e ssh)
              fi

              "''${ssh_command[@]}" \
                "''${ssh_args[@]}" \
                "$target_host" \
                sh -s < "$bootstrap_script"
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
