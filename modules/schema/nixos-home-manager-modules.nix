{
  lib,
  inputs,
  ...
}:
{
  options.aw1cks.modules.nixos-home-manager = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {
      default = inputs.home-manager.nixosModules.home-manager;
    };
    description = "Home-manager modules to embed within NixOS via the HM NixOS module.";
  };
}
