{ ... }:
{
  configurations.nixos.desktop = {
    module = {
      imports = [
        ./hardware-configuration.nix
        ./disko.nix
      ];

      boot.loader.grub.devices = [ ];

      system.stateVersion = "25.05";
    };

    home = {
      home.stateVersion = "25.05";
    };
  };

  configurations.home."alex@desktop" = {
    nvidia = {
      enable = true;
      pinFile = ./nvidia.json;
    };
    module = {
      modules.lazyvim.enable = true;
      home = {
        stateVersion = "25.05";
      };
    };
  };
}
