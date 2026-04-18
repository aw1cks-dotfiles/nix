{ config, inputs, ... }:
let
  sharedHomeModule = {
    imports = [
      inputs.noctalia.homeModules.default
      ./noctalia-home.nix
    ];
  };
in
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
        inputs.niri.nixosModules.niri
        config.aw1cks.modules.nixos.nvidia
        config.aw1cks.modules.nixos.ly
        ./hardware-configuration.nix
        ./disko.nix
        ./niri.nix
        ./noctalia.nix
      ];

      boot.loader.grub.devices = [ ];

      niri-flake.cache.enable = true;

      services.openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      security.sudo.wheelNeedsPassword = false;

      # Run the embedded Home Manager activation after the user manager exists
      # so user units like Noctalia autostart are actually reloaded.
      systemd.services.home-manager-alex.after = [ "systemd-user-sessions.service" ];
      systemd.services.home-manager-alex.wants = [ "systemd-user-sessions.service" ];

      system.stateVersion = "25.05";
    };

    home = {
      imports = [ sharedHomeModule ];

      home.stateVersion = "25.05";
    };
  };

  configurations.home."alex@desktop" = {
    nvidia = {
      enable = true;
      pinFile = ./nvidia.json;
    };
    module = {
      imports = [ sharedHomeModule ];

      modules.lazyvim.enable = true;

      home.stateVersion = "25.05";
    };
  };
}
