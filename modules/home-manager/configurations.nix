{
  lib,
  config,
  inputs,
  ...
}:
{
  options.configurations.home = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
          };
          system = lib.mkOption {
            type = lib.types.str;
            description = "System string, e.g. x86_64-linux or aarch64-darwin.";
          };
        };
      }
    );
    default = { };
  };

  config.flake.homeConfigurations = lib.mapAttrs (
    _name:
    { module, system }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      modules = [
        module
        inputs.agenix.homeManagerModules.default
        inputs.stylix.homeModules.stylix
      ];
    }
  ) config.configurations.home;
}
