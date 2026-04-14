{ config, inputs, pkgs, ... }:
{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = 
          if config.my.system.isVmBuild then "/dev/vda" else "/dev/sda";
        imageName = "${config.networking.hostName}";
        imageSize = "15G";
        content = {
          type = "gpt";
          partitions = {
            bios_boot = {
              size = "1M";
              type = "EF02";
            };
            zramSwap = {
              size = "1G";
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
    writebackDevice = "/dev/sda2";
  };
  # https://wiki.archlinux.org/title/Zram#Optimizing_swap_on_zram
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
