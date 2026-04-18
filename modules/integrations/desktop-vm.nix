{ lib, config, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isLinux (
      let
        desktopVm =
          (config.flake.nixosConfigurations.desktop.extendModules {
            modules = [
              (
                { resolvedUser, ... }:
                {
                  virtualisation.vmVariant = {
                    virtualisation = {
                      memorySize = 8192;
                      cores = 4;
                      graphics = true;
                      qemu.options = [ "-vga virtio" ];
                      forwardPorts = [
                        {
                          from = "host";
                          host.port = 2222;
                          guest.port = 22;
                        }
                      ];
                    };
                  };

                  # The desktop host imports NVIDIA-specific tuning, but the VM
                  # proves the Ly/Niri session on a QEMU virtio GPU instead.
                  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
                  boot.kernelParams = lib.mkForce [ ];
                  boot.blacklistedKernelModules = lib.mkForce [ ];

                  environment.variables = {
                    GBM_BACKEND = lib.mkForce null;
                    LIBVA_DRIVER_NAME = lib.mkForce null;
                    __GLX_VENDOR_LIBRARY_NAME = lib.mkForce null;
                  };

                  environment.sessionVariables = {
                    GBM_BACKEND = lib.mkForce null;
                    LIBVA_DRIVER_NAME = lib.mkForce null;
                    __GLX_VENDOR_LIBRARY_NAME = lib.mkForce null;
                  };

                  hardware.nvidia = {
                    nvidiaSettings = lib.mkForce false;
                    powerManagement.enable = lib.mkForce false;
                    modesetting.enable = lib.mkForce false;
                    forceFullCompositionPipeline = lib.mkForce false;
                  };

                  hardware.graphics.extraPackages = lib.mkForce [ ];

                  services.displayManager.autoLogin.enable = false;

                  # Ly takes over the local console, so the VM proving target
                  # needs a remote inspection path from the host.
                  services.openssh = {
                    enable = true;
                    openFirewall = true;
                    settings = {
                      PasswordAuthentication = false;
                      KbdInteractiveAuthentication = false;
                    };
                  };

                  # VM proof needs a disposable password-based login path for Ly.
                  users.users.${resolvedUser} = {
                    initialPassword = "vmtest";
                    openssh.authorizedKeys.keys = [
                      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKk0DAbj6jB01UtUlLWbFe6uv1kCt1TFYDRDawxV98Ie alex.wicks VDI"
                    ];
                  };

                  # VM proof is for Ly/Niri/session behavior, not bare-metal storage.
                  fileSystems."/" = lib.mkForce {
                    device = "tmpfs";
                    fsType = "tmpfs";
                    options = [ "mode=755" ];
                  };

                  fileSystems."/boot" = lib.mkForce {
                    device = "tmpfs";
                    fsType = "tmpfs";
                    options = [ "mode=755" ];
                  };

                  boot.loader.systemd-boot.enable = lib.mkForce false;
                  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
                }
              )
            ];
          }).config.system.build.vm;
      in
      {
        packages.desktop-vm = desktopVm;

        apps.desktop-vm = {
          type = "app";
          program = "${desktopVm}/bin/run-desktop-vm";
          meta.description = "Launch the repo-local desktop VM proving target";
        };
      }
    );
}
