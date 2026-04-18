{ inputs, ... }:
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
