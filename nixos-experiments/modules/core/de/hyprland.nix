{ pkgs, ... }:
{
  imports = [
    ./wayland.nix
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # withUSWM = true;
  };
}
