let
  lixModule =
    { pkgs, ... }:
    {
      nix.package = pkgs.lixPackageSets.latest.lix;
    };
in
{
  aw1cks.modules = {
    nixos.lix = lixModule;
    darwin.lix = lixModule;
  };
}
