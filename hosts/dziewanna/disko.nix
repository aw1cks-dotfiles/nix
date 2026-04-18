{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        imageName = "dziewanna";
        imageSize = "15G";
        content = {
          type = "gpt";
          partitions = {
            bios_boot = {
              size = "1M";
              type = "EF02";
            };

            zram_writeback = {
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

  # The live host is memory-constrained enough that the bootstrap/kexec path
  # needed zram writeback enabled manually; keep that encoded in the host.
  zramSwap = {
    enable = true;
    writebackDevice = "/dev/disk/by-partlabel/disk-main-zram_writeback";
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
