{ config, lib, pkgs, ... }:

{
  options.my.bootloader.bios.device = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = "The device to install the BIOS bootloader to.";
    default = null;
  };

  config = lib.mkIf (config.my.bootloader.bios.device != null) {
    boot.loader.grub = {
      enable = true;
      device = config.my.bootloader.bios.device;
    };

    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  };
}
