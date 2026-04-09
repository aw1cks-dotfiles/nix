# Nixpkgs configuration and unstable overlay
# Provides the `unstable` package set overlay for accessing bleeding-edge packages
{ inputs, lib, ... }:
let
  sharedNixpkgsModule =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      options.repo.lix.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this module should enable the shared Lix overlay and module wiring.";
      };

      options.repo.nixpkgs.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this module should manage nixpkgs config and overlays.";
      };

      config = lib.mkIf config.repo.nixpkgs.enable {
        nixpkgs = {
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            nvidia.acceptLicense = true;
          };
          overlays = lib.optional config.repo.lix.enable inputs.lix-module.overlays.default ++ [
            (_final: _prev: {
              unstable = import inputs.nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
            })
            inputs.llm-agents.overlays.default
          ];
        };
      };
    };
in
{
  flake.modules.shared.nixpkgs = sharedNixpkgsModule;

  flake.modules.home.nixpkgs =
    { config, ... }:
    {
      imports = [ sharedNixpkgsModule ];

      repo.nixpkgs.enable = !(config.submoduleSupport.externalPackageInstall or false);
    };
}
