{ config, ... }:
let
  inherit (config.flake.modules) home;
  # cat /sys/module/nvidia/version
  nvidiaDriverVersion = "595.58.03";
  # nix store prefetch-file "https://download.nvidia.com/XFree86/Linux-$(uname -m)/$(</sys/module/nvidia/version)/NVIDIA-Linux-$(uname -m)-$(</sys/module/nvidia/version).run"
  nvidiaDriverHash = "sha256-jA1Plnt5MsSrVxQnKu6BAzkrCnAskq+lVRdtNiBYKfk=";
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
          version = nvidiaDriverVersion;
          sha256 = nvidiaDriverHash;
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
