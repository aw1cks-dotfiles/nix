{ lib, config, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isLinux (
      let
        desktop = config.flake.nixosConfigurations.desktop;

        desktopVmGuestModule =
          { lib, resolvedUser, ... }:
          {
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
          };

        desktopVmVariantModule = {
          virtualisation.vmVariant = {
            virtualisation = {
              memorySize = 8192;
              cores = 4;
              graphics = true;
              qemu.options = [
                "-vga virtio"
                "-device virtio-sound-pci,audiodev=desktopvm"
                "-audiodev wav,id=desktopvm,path=/tmp/desktop-vm-audio.wav"
              ];
              forwardPorts = [
                {
                  from = "host";
                  host.port = 2222;
                  guest.port = 22;
                }
              ];
            };
          };
        };

        desktopVmTestModule = {
          virtualisation = {
            memorySize = 8192;
            cores = 4;
            graphics = true;
            qemu.options = [
              "-vga virtio"
              "-device virtio-sound-pci,audiodev=desktopvm"
              "-audiodev wav,id=desktopvm,path=/tmp/desktop-vm-audio.wav"
            ];
          };
        };

        desktopVmConfiguration = desktop.extendModules {
          modules = [
            desktopVmGuestModule
            desktopVmVariantModule
          ];
        };

        desktopVm = desktopVmConfiguration.config.system.build.vm;

        desktopVmSmoke = pkgs.testers.runNixOSTest (
          {
            lib,
            nodes,
            ...
          }:
          let
            normalUsers = lib.filterAttrs (_: user: user.isNormalUser or false) nodes.machine.users.users;
            userName = builtins.head (builtins.attrNames normalUsers);
          in
          {
            name = "desktop-vm-smoke";
            node.specialArgs = desktop._module.specialArgs;
            node.pkgsReadOnly = false;

            nodes.machine = {
              imports = desktop._module.args.modules ++ [
                desktopVmGuestModule
                desktopVmTestModule
                {
                  networking.hostName = lib.mkForce "machine";
                }
              ];
            };

            testScript = ''
              from test_driver.errors import RequestedAssertionFailed

              start_all()

              def navigate_user(machine, username, session, tty="1"):
                  session = session.lower()
                  tries = 0
                  while username not in machine.get_tty_text(tty):
                      machine.send_key("left")
                      machine.sleep(0.3)
                      if tries > 4:
                          raise RequestedAssertionFailed(f"Failed to find user:{username} in ly")
                      tries += 1

                  machine.send_key("up")

                  tries = 0
                  while session not in machine.get_tty_text(tty).lower():
                      machine.send_key("left")
                      machine.sleep(0.3)
                      if tries > 6:
                          raise RequestedAssertionFailed(f"Failed to find session:{session} in ly")
                      tries += 1

                  machine.send_key("tab")

              user_name = "${userName}"
              user_uid = machine.succeed(f"id -u {user_name}").strip()
              runtime_dir = f"/run/user/{user_uid}"

              def run_in_session(command):
                  machine.succeed(
                      f"su - {user_name} -c 'env "
                      f"XDG_RUNTIME_DIR={runtime_dir} "
                      f"DBUS_SESSION_BUS_ADDRESS=unix:path={runtime_dir}/bus "
                      f"WAYLAND_DISPLAY=$(basename $(ls {runtime_dir}/wayland-* | head -n1)) "
                      f"{command}'"
                  )

              machine.wait_until_tty_matches("1", "password")
              machine.send_key("ctrl-alt-f1")
              machine.sleep(1)

              navigate_user(machine, user_name, "niri")
              machine.send_key("tab")
              machine.send_chars("vmtest")
              machine.send_key("ret")

              machine.wait_for_file(f"{runtime_dir}/bus")
              machine.wait_until_succeeds(f"ls {runtime_dir}/wayland-*")
              machine.wait_until_succeeds(
                  f"su - {user_name} -c 'env "
                  f"XDG_RUNTIME_DIR={runtime_dir} "
                  "systemctl --user is-active niri.service'"
              )
              machine.wait_until_succeeds(f"pgrep -u {user_name} -f noctalia-shell")
              machine.succeed(f"su - {user_name} -c 'command -v wezterm && command -v zen-twilight'")

              run_in_session(
                  'wezterm start --always-new-process -- bash -lc "touch /tmp/desktop-vm-wezterm-launched; exec sleep 30" >/tmp/desktop-vm-wezterm.log 2>&1 &'
              )
              machine.wait_for_file("/tmp/desktop-vm-wezterm-launched")
              machine.wait_until_succeeds(f"pgrep -u {user_name} -f wezterm")

              run_in_session('zen-twilight file:///etc/os-release >/tmp/desktop-vm-zen.log 2>&1 &')
              machine.wait_until_succeeds(
                  f"pgrep -u {user_name} -f zen-twilight || pgrep -u {user_name} -x zen || pgrep -u {user_name} -x firefox"
              )

              run_in_session('wpctl status >/tmp/desktop-vm-audio.log 2>&1')
              machine.wait_until_succeeds("test -s /tmp/desktop-vm-audio.log")
              machine.wait_until_succeeds(
                  f"su - {user_name} -c 'env "
                  f"XDG_RUNTIME_DIR={runtime_dir} "
                  "wpctl inspect @DEFAULT_AUDIO_SINK@ >/tmp/desktop-vm-default-sink.log 2>&1'"
              )
              machine.wait_until_succeeds("test -s /tmp/desktop-vm-default-sink.log")
            '';
          }
        );
      in
      {
        packages.desktop-vm = desktopVm;
        packages.desktop-vm-smoke = desktopVmSmoke;

        apps.desktop-vm = {
          type = "app";
          program = "${desktopVm}/bin/run-desktop-vm";
          meta.description = "Launch the repo-local desktop VM proving target";
        };

        apps.desktop-vm-smoke = {
          type = "app";
          program = "${pkgs.writeShellScript "desktop-vm-smoke" ''
            exec nix build --print-out-paths --no-link .#desktop-vm-smoke
          ''}";
          meta.description = "Run the repo-local desktop VM smoke test";
        };
      }
    );
}
