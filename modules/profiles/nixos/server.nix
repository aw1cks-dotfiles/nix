{ config, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.nixos.server = {
    # Minimal shared NixOS runtime for headless and service-oriented hosts.
    imports = [
      modules.nixos.lix
      modules.nixos.nix-settings
    ];
  };
}
