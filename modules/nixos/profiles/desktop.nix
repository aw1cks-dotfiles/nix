{ config, lib, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.nixos.desktop = {
    # Keep the desktop bundle thin: shared NixOS runtime first, host-local graphics later.
    imports = [
      modules.nixos.boot
      modules.nixos.efi
      modules.nixos.latest-kernel
      modules.nixos.network
      modules.nixos.nix-settings
      modules.nixos.pipewire
      modules.nixos.resolved
      modules.nixos.systemd-boot
      modules.nixos.vpn-client
      modules.nixos.wayland
    ];

    # Desktops will likely need to run non-Nix binaries (e.g. UV python runtime)
    programs.nix-ld.enable = true;

    # Desktop hosts can opt into a richer shell baseline than servers.
    aw1cks.user.shellPolicy = lib.mkDefault "zsh";
  };
}
