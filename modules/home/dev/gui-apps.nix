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
          # Stable still uses the pre-ASAR Darwin ripgrep path.
          # https://github.com/NixOS/nixpkgs/pull/543899
          (if pkgs.stdenv.hostPlatform.isDarwin then unstable.vscode else vscode)
          wireshark
        ]
        ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ zeal ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          utm
          podman-desktop
        ];
    };
}
