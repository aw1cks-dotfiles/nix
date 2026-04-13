{ lib, ... }:
{
  options.aw1cks.profiles.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named NixOS profile bundles built from aw1cks.modules.nixos.";
  };
}
