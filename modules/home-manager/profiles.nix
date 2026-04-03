{ lib, ... }:
{
  options.flake.profiles.home = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named home-manager profile bundles built from flake.modules.home.";
  };
}
