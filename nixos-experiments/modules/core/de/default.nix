{ ... }:
{
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  imports = [
    ../audio
    ./ly.nix
    ./hyprland.nix
  ];
}
