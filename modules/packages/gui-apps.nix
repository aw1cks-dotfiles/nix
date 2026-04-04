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
          firefox
          gitkraken
          ibm-plex
          meld
          mumble
          obsidian
          podman-desktop
          qbittorrent
          slack
          syncplay
          utm
          unstable.wezterm
          vscode
          wireshark
          zeal
        ]
        ++ lib.optionals pkgs.stdenv.isDarwin [
          nerd-fonts.caskaydia-mono
          zoom-us
        ];
    };
}
