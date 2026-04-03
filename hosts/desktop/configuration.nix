{ config, ... }:
let
  inherit (config.flake) profiles;
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
        profiles.home.base
        profiles.home.developer
        profiles.home.desktop
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
