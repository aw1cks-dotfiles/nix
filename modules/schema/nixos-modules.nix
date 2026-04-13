{ lib, ... }:
{
  options.aw1cks.modules.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named NixOS deferred modules. Features add entries here.";
  };
}
