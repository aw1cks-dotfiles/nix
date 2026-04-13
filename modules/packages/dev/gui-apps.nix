{ inputs, lib, ... }:
{
  aw1cks.modules.home.dev-gui-apps =
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          gitkraken
          meld
          slack
          vscode
          wireshark
          zeal
        ]
        ++ lib.optionals pkgs.stdenv.isDarwin [
          utm
          podman-desktop
        ];
    };
}
