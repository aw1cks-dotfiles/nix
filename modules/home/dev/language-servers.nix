{ ... }:
{
  aw1cks.modules.home.language-servers =
    { pkgs, ... }:
    {
      home.packages = import ./_language-servers.nix { inherit pkgs; };
    };
}
