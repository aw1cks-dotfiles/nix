{ lib, ... }:
{
  options.aw1cks.profiles.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named nix-darwin profile bundles built from aw1cks.modules.darwin.";
  };
}
