{
  lib,
  config,
  inputs,
  ...
}:
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
    _name:
    { module, system }:
    lib.nixosSystem {
      inherit system;
      modules = [
        module
        inputs.agenix.nixosModules.default
      ];
    }
  ) config.configurations.nixos;
}
