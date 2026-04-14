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
                    };
                  };

                  services.displayManager.autoLogin.enable = false;

                  # VM proof needs a disposable password-based login path for Ly.
                  users.users.${resolvedUser}.initialPassword = "vmtest";

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
