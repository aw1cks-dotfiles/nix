{ config, ... }:
let
  inherit (config.org) modules;
in
{
  org.profiles.home.work = {
    # Example downstream profile layering private workstation concerns on top of
    # the shared aw1cks base modules and profiles.
    imports = [
      modules.home.work-git
      modules.home.work-ssl-certs
    ];
  };
}
