{
  lib,
  config,
  inputs,
  ...
}:
let
  xlib = import ../_lib/default.nix;
  facts = config.flake.hostFacts;
  roleMappings = config.flake.roles.nixos;
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
            type = lib.types.str;
            description = "System string, e.g. x86_64-linux or aarch64-linux.";
          };
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    name:
    { module, system }:
    let
      hostFacts = xlib.hostFactsFor {
        inherit facts name;
        target = "nixos";
      };
    in
    lib.nixosSystem {
      inherit system;
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
            inherit name system hostFacts;
            target = "nixos";
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
      ];
    }
  ) config.configurations.nixos;
}
