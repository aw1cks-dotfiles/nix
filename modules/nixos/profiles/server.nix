{ config, lib, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.nixos.server = {
    # Thin shared server bundle: runtime baseline plus the first WAN-facing SSH posture.
    imports = [
      modules.nixos.boot
      modules.nixos.latest-kernel
      modules.nixos.network
      modules.nixos.nix-settings
      modules.nixos.server-security
    ];

    aw1cks.user.shellPolicy = lib.mkDefault "bash";
  };
}
