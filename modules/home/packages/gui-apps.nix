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
          gedit
          nautilus
          # Install both Horizon clients side by side. `-next` is the
          # .NET/Avalonia rewrite and is preferred on Wayland because the
          # classic GTK3 client still depends on a libX11/XKB workaround.
          # Classic is kept as a fallback (e.g. for environments where
          # Next's OAuth/browser flow does not work).
          omnissa-horizon-client
          omnissa-horizon-client-next
          wl-clipboard
          xclip
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
