# GUI applications - migrated from nix-old/modules/gui-apps.nix
{ lib, ... }:
{
  aw1cks.modules.home.gui-apps =
    {
      pkgs,
      ...
    }:
    let
    in
    {
      home.packages =
        with pkgs;
        [
          cascadia-code
          nerd-fonts.caskaydia-mono
          # Temporarily disabled: current calibre in pinned nixpkgs evaluates as broken on darwin.
          # calibre
          ibm-plex
          syncplay
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          gedit
          nautilus
          omnissa-horizon-client
          wl-clipboard
          xclip
          zoom-us
        ];

      programs = {
        obsidian = {
          enable = true;
          # Keep disabled until this repo opts into managing Obsidian's CLI integration.
          # cli.enable = true;
        };
      };
    };
}
