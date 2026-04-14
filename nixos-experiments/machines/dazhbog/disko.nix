{ config, inputs, pkgs, ... }:

{
  # NOTE: this will require extra setup for cross-compiling
  # see https://nixos.wiki/wiki/NixOS_on_ARM#Compiling_through_binfmt_QEMU
  disko.imageBuilder = {
    enableBinfmt = true;
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    kernelPackages = inputs.nixpkgs.legacyPackages.x86_64-linux.linuxPackages_latest;
  };
  nixpkgs.hostPlatform = "aarch64-linux";
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = 
          if config.my.system.isVmBuild then "/dev/vda" else "/dev/sda";
        imageName = "${config.networking.hostName}";
        imageSize = "30G";
        content = {
          type = "gpt";
          partitions = {
            bios_boot = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
