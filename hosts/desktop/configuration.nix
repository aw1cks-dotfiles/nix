{ config, inputs, ... }:
{
  configurations.nixos.desktop = {
    module = {
      imports = [
        inputs.nixos-hardware.nixosModules.common-pc
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        inputs.nixos-hardware.nixosModules.common-cpu-amd
        inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
        inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
        (inputs.nixos-hardware + "/common/gpu/nvidia/ampere")
        config.aw1cks.modules.nixos.nvidia
        config.aw1cks.modules.nixos.ly
        ./hardware-configuration.nix
        ./disko.nix
        ./niri.nix
        ./noctalia.nix
      ];

      boot.loader.grub.devices = [ ];

      system.stateVersion = "25.05";
    };

    home = {
      imports = [
        inputs.noctalia.homeModules.default
        ./noctalia-home.nix
      ];
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
