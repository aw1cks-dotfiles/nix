{ config, ... }:
let
  inherit (config.aw1cks) profiles;
in
{
  aw1cks.profiles.home.dev-workstation = {
    # Developer graphical workstation.
    imports = [
      profiles.home.base
      profiles.home.dev-gui
      profiles.home.interactive
      profiles.home.desktop
      profiles.home.developer
    ];
  };

  aw1cks.profiles.home.dev-gui = {
    # Developer-focused GUI applications for interactive workstations.
    imports = [
      config.aw1cks.modules.home.dev-gui-apps
    ];
  };
}
