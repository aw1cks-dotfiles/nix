# GUI applications — migrated from nix-old/modules/gui-apps.nix
{ ... }:
{
  flake.modules.home.gui-apps =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        gitkraken
        meld
        obsidian
        vscode
        unstable.wezterm
        wireshark
        zeal
      ];
    };
}
