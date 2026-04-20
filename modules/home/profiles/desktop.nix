{ config, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.home.desktop = {
    # GUI applications, browser setup, and desktop theming.
    imports = [
      modules.home.fonts-theme
      modules.home.gui-apps
      modules.home.stylix-theme
      modules.home.wezterm
      modules.home.zen-browser
    ];
  };
}
