{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.base = {
    # Daily shell and nix tooling shared by all current home hosts.
    imports = [
      modules.home.nixpkgs
      modules.home.home-manager
      modules.home.cli-tools
      modules.home.git
      modules.home.git-config
      modules.home.nix-settings
    ];
  };
}
