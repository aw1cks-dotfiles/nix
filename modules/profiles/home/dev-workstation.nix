{ config, ... }:
let
  inherit (config.flake) profiles;
in
{
  flake.profiles.home.dev-workstation = {
    # Developer graphical workstation.
    imports = [
      profiles.home.base
      profiles.home.dev-gui
      profiles.home.interactive
      profiles.home.desktop
      profiles.home.developer
    ];
  };

  flake.profiles.home.dev-gui = {
    # Developer-focused GUI applications for interactive workstations.
    imports = [
      config.flake.modules.home.dev-gui-apps
    ];
  };
}
