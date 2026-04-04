{ config, ... }:
let
  inherit (config.flake) profiles;
in
{
  configurations.home."alex@desktop" = {
    system = "x86_64-linux";
    nvidia = {
      enable = true;
      pinFile = ./nvidia.json;
    };
    module = {
      imports = [
        profiles.home.base
        profiles.home.developer
        profiles.home.desktop
      ];

      home = {
        username = "alex";
        homeDirectory = "/home/alex";
        stateVersion = "25.05";
      };

      programs.man.enable = true;
      manual = {
        html.enable = true;
        manpages.enable = true;
      };
    };
  };
}
