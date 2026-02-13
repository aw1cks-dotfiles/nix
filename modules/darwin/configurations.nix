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
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
      }
    );
    default = { };
  };

  config.flake.darwinConfigurations = lib.mapAttrs (
    _name:
    { module }:
    inputs.nix-darwin.lib.darwinSystem {
      modules = [
        module
        inputs.agenix.darwinModules.default
      ];
    }
  ) config.configurations.darwin;
}
