{ config, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.home.multimedia = {
    imports = [
      modules.home.multimedia-apps
    ];
  };
}
