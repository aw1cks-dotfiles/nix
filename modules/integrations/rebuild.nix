{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      rebuild = pkgs.writeShellApplication {
        name = "rebuild";
        runtimeInputs = [ pkgs.nh ];
        text = ''
          case "$(uname -s)" in
            Darwin) target=darwin ;;
            Linux)
              if [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
                echo "WSL is not supported yet" >&2
                exit 1
              elif [[ -e /run/current-system/nixos-version ]]; then
                target=os
              else
                target=home
              fi
              ;;
            *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
          esac
          flake="''${1:-.}"
          if (( $# > 0 )); then shift; fi
          # NH hides activation output by default, including Home Manager's
          # "Skipping reload" warning, which can leave changed units running
          # their old definitions without any visible indication.
          exec nh "$target" switch --show-activation-logs "$flake" "$@"
        '';
        meta.description = "Switch the current machine with visible activation logs";
      };
      update = pkgs.writeShellApplication {
        name = "update";
        runtimeInputs = [ pkgs.gh ];
        text = ''
          # This app updates the enclosing checkout, not another flake.
          for arg in "$@"; do
            case "$arg" in
              --flake|--flake=*)
                echo "update targets the enclosing checkout; run it from the desired checkout instead of using --flake" >&2
                exit 2
                ;;
            esac
          done
          # Locate the root without changing how Nix resolves caller-relative
          # input overrides and lock-file paths.
          root="$(
            while [[ ! -f flake.nix ]]; do
              if [[ "$PWD" == / ]]; then
                echo "No enclosing flake.nix found" >&2
                exit 1
              fi
              cd ..
            done
            pwd -P
          )"
          # Keep credentials out of NH's environment and elevation arguments.
          # Failed token lookup must still allow an unauthenticated fetch.
          set +x
          if tok="$(gh auth token --hostname github.com 2>/dev/null)"; then
            if [[ -n "$tok" && "$tok" != *[[:space:]]* ]]; then
              export NIX_CONFIG="''${NIX_CONFIG-}
          extra-access-tokens = github.com=$tok"
            fi
          fi
          unset tok
          nix flake update "$@"
          cd "$root"
          nix run .#write-flake
          # Fetch sources now so later rebuilds need no injected credentials.
          nix flake archive .
        '';
        meta.description = "Update inputs, regenerate flake.nix, and fetch all input sources";
      };
      clean = pkgs.writeShellApplication {
        name = "clean";
        text = ''
          mode=all
          case "''${1-}" in
            --gc-only) mode=gc; shift ;;
            --optimise-only) mode=optimise; shift ;;
          esac
          days="''${1:-7}"
          nix_command=(nix)
          if [[ "$(uname -s)" == Darwin ]]; then
            nix_command=(sudo -H nix)
          fi
          if [[ "$mode" != optimise ]]; then
            if [[ "$(uname -s)" == Darwin ]]; then
              generations="+$days"
              if [[ "$days" == 0 ]]; then generations=old; fi
              sudo -H nix-env --profile /nix/var/nix/profiles/system --delete-generations "$generations"
            elif [[ "$days" == 0 ]]; then
              nix profile wipe-history
            else
              nix profile wipe-history --older-than "''${days}d"
            fi
            "''${nix_command[@]}" store gc
          fi
          if [[ "$mode" != gc ]]; then
            "''${nix_command[@]}" store optimise
          fi
        '';
        meta.description = "Prune generations, collect garbage, and optimise the store (default: 7 days)";
      };
    in
    {
      apps = {
        rebuild = {
          type = "app";
          program = "${rebuild}/bin/rebuild";
          meta.description = rebuild.meta.description;
        };
        default = {
          type = "app";
          program = "${rebuild}/bin/rebuild";
          meta.description = rebuild.meta.description;
        };
        update = {
          type = "app";
          program = "${update}/bin/update";
          meta.description = update.meta.description;
        };
        clean = {
          type = "app";
          program = "${clean}/bin/clean";
          meta.description = clean.meta.description;
        };
      };
    };
}
