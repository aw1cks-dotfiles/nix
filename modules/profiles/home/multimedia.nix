{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.multimedia = {
    imports = [
      modules.home.multimedia-apps
    ];
  };
}
