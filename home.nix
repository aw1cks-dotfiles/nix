{ lib, pkgs, ... }:
{
  home = {
    stateVersion = "25.05";

    username = "alex";
    homeDirectory = "/home/alex";

    stateVersion = "25.05";

    packages = with pkgs; [
      hello
    ];
  };
}
