{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      packages.colimabar = import ./_colimabar-package.nix { inherit pkgs; };
    };

  aw1cks.modules.home.colimabar =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.modules.colimabar.enable = lib.mkEnableOption "the manual Colima menu-bar app";
      config = lib.mkIf config.modules.colimabar.enable {
        assertions = [
          {
            assertion = pkgs.stdenv.hostPlatform.isDarwin;
            message = "ColimaBar requires macOS.";
          }
        ];
        home.packages = [ (import ./_colimabar-package.nix { inherit pkgs; }) ];
      };
    };
}
