{ config, ... }:
let
  inherit (config.flake) profiles;
in
{
  configurations.darwin.mbp = {
    system = "aarch64-darwin";
    user = "alex";
    homeDirectory = "/Users/alex";
    module = {
      imports = [
        profiles.darwin.desktop
      ];

      networking.hostName = "mbp";
      nixpkgs.hostPlatform = "aarch64-darwin";
      system.stateVersion = 6;
    };
    home = {
      imports = [
        profiles.home.base
        profiles.home.developer
        profiles.home.desktop
      ];

      home = {
        stateVersion = "25.11";
      };
    };
  };
}
