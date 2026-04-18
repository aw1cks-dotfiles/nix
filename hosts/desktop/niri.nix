{ pkgs, ... }:
{
  programs.niri.enable = true;

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.niri = {
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
