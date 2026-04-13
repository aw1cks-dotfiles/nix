{ lib, ... }:
{
  options.aw1cks.profiles.home = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named home-manager profile bundles built from aw1cks.modules.home.";
  };
}
