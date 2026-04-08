{
  lib,
  config,
  inputs,
  ...
}:
let
  facts = config.flake.hostFacts;
  roleMappings = config.flake.roles.nixos;

  hostFactsFor =
    name:
    if builtins.hasAttr name facts then
      facts.${name}
    else
      throw "configurations.nixos.${name}: missing entry in hosts/facts.nix.";

  roleModulesFor =
    hostFacts:
    roleMappings.base
    ++ lib.concatMap (role: roleMappings.roles.${role} or [ ]) (hostFacts.roles or [ ]);
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
      hostFacts = hostFactsFor name;
    in
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit hostFacts;
      };
      modules = [
        {
          assertions = [
            {
              assertion = hostFacts.system == system;
              message = "configurations.nixos.${name}: facts system ${hostFacts.system} does not match declared system ${system}.";
            }
            {
              assertion = hostFacts.kind == "nixos";
              message = "configurations.nixos.${name}: facts kind must be nixos, got ${hostFacts.kind}.";
            }
          ];
        }
      ]
      ++ roleModulesFor hostFacts
      ++ [
        module
        inputs.agenix.nixosModules.default
      ];
    }
  ) config.configurations.nixos;
}
