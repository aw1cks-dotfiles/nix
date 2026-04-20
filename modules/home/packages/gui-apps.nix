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
          zoom-us
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          nautilus
          omnissa-horizon-client
          wl-clipboard
          xclip
        ];

      programs = {
        formiko.enable = pkgs.stdenv.isLinux;
        obsidian = {
          enable = true;
          # not available on hm-25.11 yet
          # cli.enable = true;
        };
      };
    };
}
