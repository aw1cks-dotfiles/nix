{ options, config, lib, pkgs, ... }:
{
  my.system.type = "server";

  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./network.nix

    ../../modules/core/network
    ../../modules/core/security
    ../../modules/core/nix
    ../../modules/core/locale

    ./murmur.nix
  ];

  environment.systemPackages = with pkgs; [
    git
    neovim
    wget
    curl
    lshw
    htop
  ];

  system.stateVersion = "25.05";
}
