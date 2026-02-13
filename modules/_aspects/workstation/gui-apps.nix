# GUI applications — migrated from dendritic-lib/modules/packages/gui-apps.nix
{ dl, ... }:
{
  dl.workstation-gui-apps.homeManager =
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
