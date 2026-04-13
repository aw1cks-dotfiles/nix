{ config, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.home.base = {
    # Minimal Home Manager and Nix plumbing shared by all home hosts.
    imports = [
      modules.home.home-manager
      modules.home.nix-settings
      modules.home.nixpkgs
    ];
  };
}
