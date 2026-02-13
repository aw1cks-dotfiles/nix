{ lib, ... }:
{
  options.flake.modules.nixos-home-manager = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Home-manager modules to embed within NixOS via the HM NixOS module.";
  };
}
