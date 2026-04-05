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
        profiles.home.dev-workstation
        profiles.home.multimedia
      ];

      home = {
        username = "alex";
        homeDirectory = "/home/alex";
        stateVersion = "25.05";
      };
    };
  };
}
