# GUI applications — migrated from nix-old/modules/gui-apps.nix
{ lib, ... }:
{
  flake.modules.home.gui-apps =
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          cascadia-code
          # Temporarily disabled: current calibre in pinned nixpkgs evaluates as broken on darwin.
          # calibre
          gitkraken
          ibm-plex
          meld
          mumble
          obsidian
          qbittorrent
          slack
          syncplay
          unstable.wezterm
          vscode
          wireshark
          zeal
        ]
        ++ lib.optionals pkgs.stdenv.isDarwin [
          nerd-fonts.caskaydia-mono
          podman-desktop
          utm
          zoom-us
        ];
    };
}
