{ config, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.darwin.desktop = {
    imports = [
      modules.darwin.nix-settings
      modules.darwin.homebrew
    ];
  };
}
