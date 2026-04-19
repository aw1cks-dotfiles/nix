{ pkgs, ... }:
{
  programs.niri.enable = true;

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
