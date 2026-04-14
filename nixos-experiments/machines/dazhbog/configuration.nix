{ options, config, lib, pkgs, ... }:
{
  my.system.type = "server";

  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./network.nix
    ../../modules/core/bootloader

    ../../modules/core/network
    ../../modules/core/security
    ../../modules/core/nix
    ../../modules/core/locale
  ];

  system.stateVersion = "25.05";
}
