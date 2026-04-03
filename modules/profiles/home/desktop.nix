{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.desktop = {
    # GUI applications, browser setup, and desktop theming.
    imports = [
      modules.home.gui-apps
      modules.home.zen-browser
      modules.home.stylix-theme
    ];
  };
}
