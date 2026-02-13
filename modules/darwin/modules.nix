{ lib, ... }:
{
  options.flake.modules.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named nix-darwin deferred modules.";
  };
}
