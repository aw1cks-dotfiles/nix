{
  lib,
  config,
  inputs,
  ...
}:
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
          };
          system = lib.mkOption {
            type = lib.types.str;
            description = "System string, e.g. x86_64-darwin or aarch64-darwin.";
          };
          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "User name for home-manager configuration.";
          };
          homeDirectory = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Home directory for the primary darwin user and embedded Home Manager config.";
          };
          home = lib.mkOption {
            type = lib.types.nullOr lib.types.deferredModule;
            default = null;
            description = "Optional home-manager configuration to embed via the HM darwin module.";
          };
        };
      }
    );
    default = { };
  };

  config.flake.darwinConfigurations = lib.mapAttrs (
    name:
    {
      module,
      system,
      user ? null,
      homeDirectory ? null,
      home ? null,
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        ({
          assertions = [
            {
              assertion = home == null || user != null;
              message = "configurations.darwin.${name}: `user` is required when `home` is set.";
            }
            {
              assertion = home == null || homeDirectory != null;
              message = "configurations.darwin.${name}: `homeDirectory` is required when `home` is set.";
            }
          ];
        })
        module
        inputs.agenix.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        config.flake.modules.shared.nixpkgs
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
        (lib.mkIf (user != null) {
          system.primaryUser = lib.mkDefault user;
          nix.settings.trusted-users = lib.mkAfter [ user ];
        })
        (lib.mkIf (user != null && homeDirectory != null) {
          users.users.${user}.home = lib.mkDefault homeDirectory;
        })
        (lib.mkIf (home != null && user != null && homeDirectory != null) {
          home-manager.users.${user} = {
            imports = [
              inputs.stylix.homeModules.stylix
              home
            ];
            home.username = lib.mkDefault user;
            home.homeDirectory = lib.mkDefault homeDirectory;
          };
        })
      ];
    }
  ) config.configurations.darwin;
}
