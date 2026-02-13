{ config, ... }:
let
  inherit (config.flake.modules) home;
in
{
  configurations.home."alex@desktop" = {
    system = "x86_64-linux";
    module = {
      imports = [
        home.nixpkgs
        home.home-manager
        home.cli-tools
        home.git
        home.git-config
        home.dev-tools
        home.ai
        home.containers
        home.rust
        home.java
        home.zen-browser
        home.gui-apps
        home.nix-settings
        home.stylix-theme
      ];

      home = {
        username = "alex";
        homeDirectory = "/home/alex";
        stateVersion = "25.05";
      };

      targets.genericLinux = {
        enable = true;
        gpu.nvidia = {
          enable = true;
          version = "590.48.01";
          sha256 = "sha256-ueL4BpN4FDHMh/TNKRCeEz3Oy1ClDWto1LO/LWlr1ok=";
        };
      };

      programs.man.enable = true;
      manual = {
        html.enable = true;
        manpages.enable = true;
      };
    };
  };
}
