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

    modules.ai.chatgpt.enable = lib.mkDefault true;
  };
}
