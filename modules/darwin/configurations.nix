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
        };
      }
    );
    default = { };
  };

  config.flake.darwinConfigurations = lib.mapAttrs (
    _name:
    { module, system }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      modules = [
        module
        inputs.agenix.darwinModules.default
      ];
    }
  ) config.configurations.darwin;
}
