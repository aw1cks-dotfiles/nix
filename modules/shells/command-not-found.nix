{ ... }:
{
  flake.modules.home.command-not-found =
    { config, pkgs, ... }:
    let
      commandNotFoundHook = pkgs.replaceVars ./files/command-not-found.sh {
        nixLocate = "${config.programs.nix-index.package}/bin/nix-locate";
      };
    in
    {
      assertions = [
        {
          assertion = !(config.programs.command-not-found.enable or false);
          message = ''
            `programs.command-not-found.enable` cannot be used with `flake.modules.home.command-not-found`.
            This module installs a custom nix-index-backed command-not-found hook with opinionated declarative guidance.
          '';
        }
      ];

      programs = {
        bash.initExtra = ''
          source ${commandNotFoundHook}

          command_not_found_handle() {
            __dendritic_command_not_found "$@"
          }
        '';

        zsh.initContent = ''
          source ${commandNotFoundHook}

          command_not_found_handler() {
            __dendritic_command_not_found "$@"
          }
        '';
      };
    };
}
