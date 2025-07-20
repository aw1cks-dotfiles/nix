{ lib, pkgs, ... }:
{
  # Make sure home-manager manages itself so it doesn't get GC'd
  programs.home-manager.enable = true;

  home = {
    stateVersion = "25.05";

    username = "alex";
    homeDirectory = "/home/alex";

    packages = with pkgs; [
      hello
    ];
  };
}
