# Git companion packages (git itself, delta, and git-lfs are managed by git-config module)
{ ... }:
{
  flake.modules.home.git =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        difftastic
        git-doc
        gg-jj
        gh
        gh-f
        jjui
        jujutsu
        onefetch
        tig
      ];
    };
}
