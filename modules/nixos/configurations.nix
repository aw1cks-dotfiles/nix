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
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
          description = "The NixOS module for this configuration.";
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    _name:
    { module }:
    lib.nixosSystem {
      modules = [
        module
        inputs.agenix.nixosModules.default
      ];
    }
  ) config.configurations.nixos;
}
