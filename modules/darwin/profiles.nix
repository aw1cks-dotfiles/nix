{ lib, ... }:
{
  options.flake.profiles.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "Named nix-darwin profile bundles built from flake.modules.darwin.";
  };
}
