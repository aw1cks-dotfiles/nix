{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.darwin.desktop = {
    imports = [
      modules.darwin.nix-settings
      modules.darwin.homebrew
    ];
  };
}
