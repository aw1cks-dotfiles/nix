{
  lib,
  config,
  inputs,
  ...
}:
let
  xlib = import ../_lib/default.nix;
  facts = config.aw1cks.hostFacts;
  roleMappings = config.aw1cks.roles.nixos;
  homeRoleMappings = config.aw1cks.roles.home;
in
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
            description = "The NixOS module for this configuration.";
          };
          system = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional system string, e.g. x86_64-linux or aarch64-linux. Defaults from host facts when omitted.";
          };
          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "User name for embedded Home Manager configuration.";
          };
          homeDirectory = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Home directory for the primary NixOS user and embedded Home Manager config.";
          };
          home = lib.mkOption {
            type = lib.types.nullOr lib.types.deferredModule;
            default = null;
            description = "Optional Home Manager configuration to embed via the HM NixOS module.";
          };
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
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
        target = "nixos";
      };
      resolvedSystem = if system != null then system else hostFacts.system;
      identity = xlib.selectedIdentityFor {
        inherit config hostFacts;
      };
      resolvedUser = if user != null then user else hostFacts.user or identity.username;
      resolvedHomeDirectory =
        if homeDirectory != null then
          homeDirectory
        else
          xlib.resolvedHomeDirectoryFor {
            inherit hostFacts identity;
            system = resolvedSystem;
            target = "nixos";
          };
    in
    lib.nixosSystem {
      system = resolvedSystem;
      inherit
        (xlib.constructorArgsFor {
          inherit hostFacts;
          target = "nixos";
        })
        specialArgs
        ;
      modules = [
        (xlib.mkAssertionModule (
          xlib.targetAssertions {
            inherit name hostFacts;
            system = resolvedSystem;
            target = "nixos";
            extra =
              xlib.validateRolesFor {
                allMappings = config.aw1cks.roles;
                inherit hostFacts name;
                target = "nixos";
              }
              ++ [
                {
                  assertion = resolvedUser != null;
                  message = "configurations.nixos.${name}: resolved identity username is required for NixOS hosts.";
                }
                {
                  assertion = resolvedHomeDirectory != null;
                  message = "configurations.nixos.${name}: resolved identity homeDirectory is required for NixOS hosts.";
                }
              ];
          }
        ))
      ]
      ++ xlib.roleModulesFor {
        mappings = roleMappings;
        inherit hostFacts;
      }
      ++ xlib.baseModulesFor {
        inherit inputs config;
        target = "nixos";
      }
      ++ [
        module
        {
          nixpkgs.hostPlatform = lib.mkDefault hostFacts.system;
          networking.hostName = lib.mkDefault (hostFacts.hostName or name);
        }
        (lib.mkIf (resolvedUser != null) {
          users.users.${resolvedUser}.home = lib.mkDefault resolvedHomeDirectory;
        })
        (lib.mkIf (home != null && resolvedUser != null && resolvedHomeDirectory != null) {
          imports = [ config.aw1cks.modules.nixos-home-manager.default ];

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${resolvedUser} = xlib.mkHomeUserModule {
            inherit resolvedUser resolvedHomeDirectory;
            imports =
              xlib.roleModulesFor {
                mappings = homeRoleMappings;
                inherit hostFacts;
              }
              ++ xlib.baseModulesFor {
                inherit inputs config;
                target = "nixosEmbedded";
              }
              ++ [ home ];
          };
        })
      ];
    }
  ) config.configurations.nixos;
}
