{
  lib,
  config,
  inputs,
  ...
}:
let
  xlib = import ./_lib.nix;
  facts = config.aw1cks.hostFacts;
  darwinRoleMappings = config.aw1cks.roles.darwin;
  homeRoleMappings = config.aw1cks.roles.home;
in
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
          };
          system = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional system string, e.g. x86_64-darwin or aarch64-darwin. Defaults from host facts when omitted.";
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
      system ? null,
      user ? null,
      homeDirectory ? null,
      home ? null,
    }:
    let
      hostFacts = xlib.hostFactsFor {
        inherit facts name;
        target = "darwin";
      };
      identity = xlib.selectedIdentityFor {
        inherit config hostFacts;
      };
      resolvedSystem = if system != null then system else hostFacts.system;
      resolvedUser = if user != null then user else hostFacts.user or identity.username;
      resolvedHomeDirectory =
        if homeDirectory != null then
          homeDirectory
        else
          xlib.resolvedHomeDirectoryFor {
            inherit hostFacts identity;
            system = resolvedSystem;
            target = "darwin";
          };
    in
    inputs.nix-darwin.lib.darwinSystem {
      system = resolvedSystem;
      pkgs = xlib.configuredPkgsFor {
        inherit inputs;
        system = resolvedSystem;
      };
      inherit
        (xlib.constructorArgsFor {
          inherit hostFacts;
          target = "darwin";
        })
        specialArgs
        ;
      modules = [
        (xlib.mkAssertionModule (
          xlib.targetAssertions {
            inherit name hostFacts;
            system = resolvedSystem;
            target = "darwin";
            extra =
              xlib.validateRolesFor {
                allMappings = config.aw1cks.roles;
                inherit hostFacts name;
                target = "darwin";
              }
              ++ [
                {
                  assertion = resolvedUser != null;
                  message = "configurations.darwin.${name}: resolved identity username is required for darwin hosts.";
                }
                {
                  assertion = resolvedHomeDirectory != null;
                  message = "configurations.darwin.${name}: resolved identity homeDirectory is required for darwin hosts.";
                }
              ];
          }
        ))
      ]
      ++ xlib.roleModulesFor {
        mappings = darwinRoleMappings;
        inherit hostFacts;
      }
      ++ xlib.baseModulesFor {
        inherit inputs config;
        target = "darwin";
      }
      ++ [
        module
        {
          nixpkgs.hostPlatform = lib.mkDefault hostFacts.system;
          networking.hostName = lib.mkDefault (hostFacts.hostName or name);
        }
        (lib.mkIf (resolvedUser != null) {
          system.primaryUser = lib.mkDefault resolvedUser;
          nix.settings.trusted-users = lib.mkAfter [ resolvedUser ];
        })
        (lib.mkIf (resolvedUser != null && resolvedHomeDirectory != null) {
          users.users.${resolvedUser}.home = lib.mkDefault resolvedHomeDirectory;
        })
        (lib.mkIf (home != null && resolvedUser != null && resolvedHomeDirectory != null) {
          home-manager.users.${resolvedUser} = xlib.mkHomeUserModule {
            inherit resolvedUser resolvedHomeDirectory;
            imports =
              xlib.roleModulesFor {
                mappings = homeRoleMappings;
                inherit hostFacts;
              }
              ++ xlib.baseModulesFor {
                inherit inputs config;
                target = "homeEmbedded";
              }
              ++ [ home ];
          };
        })
      ];
    }
  ) config.configurations.darwin;
}
