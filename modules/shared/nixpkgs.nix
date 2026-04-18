# Shared constructor-owned nixpkgs marker modules.
# Constructors now own configured package-set creation for each platform.
{ lib, ... }:
{
  options.aw1cks.modules.shared = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named shared deferred modules available across targets.";
  };

  config = {
    aw1cks.modules.shared.nixpkgs = { };
    aw1cks.modules.home.nixpkgs = { };
  };
}
