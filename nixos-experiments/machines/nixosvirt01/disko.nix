{ config, pkgs, ... }:

{
  disko.imageBuilder = { pkgs = pkgs; kernelPackages = pkgs.linuxPackages_latest; };
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = "/dev/vda";
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
            zramSwap = {
              size = "8G";
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
  zramSwap = {
    enable = true;
    writebackDevice = "/dev/vda3";
  };
  # https://wiki.archlinux.org/title/Zram#Optimizing_swap_on_zram
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
