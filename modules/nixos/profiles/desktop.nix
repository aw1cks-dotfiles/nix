{ config, lib, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.nixos.desktop = {
    # Keep the desktop bundle thin: shared NixOS runtime + sensible
    # baseline kernel. Hosts wanting the high-perf stack also import
    # `aw1cks.profiles.nixos.desktop-perf` directly (sibling profile).
    #
    # Profile-imports-profile nesting is intentionally avoided here
    # because nested deferredModule indirection causes option-decl
    # duplication for atomic modules that declare options.
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
      modules.nixos.fonts
    ];

    # Desktops will likely need to run non-Nix binaries (e.g. UV python runtime)
    programs.nix-ld.enable = true;

    # Desktop hosts can opt into a richer shell baseline than servers.
    aw1cks.user.shellPolicy = lib.mkDefault "zsh";
  };
}
