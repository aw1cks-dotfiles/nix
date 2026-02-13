{ ... }:
{
  flake.modules.home.stylix-theme =
    { pkgs, ... }:
    {
      stylix = {
        enable = true;
        autoEnable = false;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/oxocarbon-dark.yaml";
      };
    };
}
