{ options, config, lib, pkgs, ... }:
{
  my.system.type = "desktop";

  imports = [
    ./disko.nix

    ../../modules/core/virtualisation/qemu-guest.nix
    ../../modules/core/bootloader

    ../../modules/core/network
    ../../modules/core/security
    ../../modules/core/nix
    ../../modules/core/locale

    ../../modules/core/shell/zsh.nix
    ../../modules/core/de
  ];

  networking.hostName = "nixosvirt01";
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    git
    rsync
    zsh
    neovim
    wget
    curl
    lshw
    htop

    kitty
    fastfetch
  ];

  system.stateVersion = "25.05";
}
