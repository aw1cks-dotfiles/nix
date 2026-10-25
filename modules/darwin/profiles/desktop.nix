{ config, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  aw1cks.profiles.darwin.desktop = { lib, ... }: {
    imports = [
      modules.darwin.nix-settings
      modules.darwin.homebrew
      modules.darwin.chatgpt-desktop
    ];

    aw1cks.chatgptDesktop.enable = lib.mkDefault true;
  };
}
