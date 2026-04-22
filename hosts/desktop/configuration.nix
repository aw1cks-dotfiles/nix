{
  lib,
  config,
  inputs,
  ...
}:
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
        config.aw1cks.profiles.nixos.desktop
        config.aw1cks.profiles.nixos.desktop-perf
        inputs.nixos-hardware.nixosModules.common-pc
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        inputs.nixos-hardware.nixosModules.common-cpu-amd
        # NB: deliberately NOT importing common-cpu-amd-pstate; it would
        # append `amd_pstate=active` to kernelParams and conflict with
        # desktop-perf's `amd_pstate=guided` setting (kernel uses the
        # last-passed param, but order isn't guaranteed). desktop-perf
        # owns this for high-perf hosts.
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

      # High-performance tuning stack tailored to this 5950X + RTX 3090 + 64 GB box.
      # The desktop-perf profile is imported above; importing == enabling.
      # Sub-options below fine-tune for this machine's specific hardware.
      #
      # 5950X is Zen 3 -> AVX2/FMA/BMI2 supported, no AVX-512.
      # Use the v3 kernel build; thin LTO (default) is on.
      aw1cks.cachyosKernel = {
        variant = "latest";
        lto = true;
        march = "x86_64-v3";
      };

      # [ASSUMPTION] This is a single-user trusted desktop, so trading CPU
      # vulnerability mitigations for latency/throughput is intentional here
      # and should stay host-local rather than profile-wide.
      aw1cks.desktop.highPerf.mitigationsOff = true;

      # scx_lavd is the right pick for mixed gaming/dev. Override with
      # `scx_bpfland` (or others) if you want to A/B test.
      aw1cks.scx.scheduler = "scx_lavd";

      # Keep bpftune constrained to the repo's network-layer allowlist.
      # tcp_conn_tuner.so stays excluded so desktop-perf keeps owning the
      # static bbr/fq choice instead of adding a second congestion-control
      # policy layer.
      aw1cks.bpftune.enable = true;

      # 16 GiB swapfile + zstd-compressed zswap. No hibernation today.
      # When the root FS moves into LUKS later, recreate the swapfile on
      # the encrypted FS and add resume=/resume_offset for hibernation.
      aw1cks.zswapSwapfile = {
        swapfilePath = "/var/swapfile";
        swapfileSizeMiB = 16384;
        zswap = {
          compressor = "zstd";
          zpool = "zsmalloc";
          maxPoolPercent = 20;
        };
      };

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

      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="409e", TAG+="uaccess"
      '';

      users.users.alex.extraGroups = lib.mkAfter [ "input" ];

      # Run the embedded Home Manager activation after the user manager exists
      # so user units like Noctalia autostart are actually reloaded.
      systemd.services.home-manager-alex.after = [ "systemd-user-sessions.service" ];
      systemd.services.home-manager-alex.wants = [ "systemd-user-sessions.service" ];

      time.timeZone = "Europe/London";

      system.stateVersion = "25.05";
    };

    home = {
      imports = [ sharedHomeModule ];
      modules.lazyvim.enable = true;
      home.stateVersion = "25.05";
    };
  };

  # LEGACY: old Arch install with home-manager.
  # Superceded by NixOS config.
  configurations.home."alex@desktop" = {
    nvidia = {
      enable = true;
      pinFile = ./nvidia.json;
    };
    module = {
      modules.lazyvim.enable = true;
      home.stateVersion = "25.05";
    };
  };
}
