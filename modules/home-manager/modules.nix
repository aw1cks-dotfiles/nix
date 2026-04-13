{ lib, ... }:
{
  options.aw1cks.modules.home = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named home-manager deferred modules.";
  };
}
