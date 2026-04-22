{ lib, ... }:
let
  compressorModule =
    compressor:
    {
      lz4 = "lz4";
      zstd = "zstd";
      lzo = "lzo";
      deflate = "deflate";
    }
    .${compressor};

  zpoolModule =
    zpool:
    {
      zsmalloc = "zsmalloc";
      z3fold = "z3fold";
      zbud = "zbud";
    }
    .${zpool};
in
{
  # Managed swapfile + zswap (compressed in-RAM cache backed by the
  # swapfile on disk). Does NOT configure hibernation (requires resume=
  # + resume_offset, intentionally out of scope here).
  #
  # CONSTRAINT: swapfile path must live on a non-CoW filesystem
  # (ext4/xfs are fine; btrfs needs `btrfs filesystem mkswapfile` on a
  # nodatacow subvolume and is not handled here).
  #
  # Owns the `aw1cks.zswapSwapfile.*` option surface.
  aw1cks.modules.nixos.zswap-swapfile =
    { config, ... }:
    let
      cfg = config.aw1cks.zswapSwapfile;
    in
    {
      options.aw1cks.zswapSwapfile = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable a managed swapfile + zswap.";
        };

        swapfilePath = lib.mkOption {
          type = lib.types.str;
          default = "/var/swapfile";
          description = "Absolute path to the swapfile. Must be on ext4/xfs (not btrfs).";
        };

        swapfileSizeMiB = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 16384;
          description = ''
            Swapfile size in MiB. 16 GiB is enough headroom for zswap on a
            64 GiB desktop without hibernation. For hibernation, set to >=
            RAM size and configure resume= separately.
          '';
        };

        zswap = {
          compressor = lib.mkOption {
            type = lib.types.enum [
              "lz4"
              "zstd"
              "lzo"
              "deflate"
            ];
            default = "zstd";
            description = "zswap compressor. zstd gives the best ratio at modest CPU cost.";
          };

          zpool = lib.mkOption {
            type = lib.types.enum [
              "zsmalloc"
              "z3fold"
              "zbud"
            ];
            default = "zsmalloc";
            description = "zswap zpool allocator. zsmalloc is densest.";
          };

          maxPoolPercent = lib.mkOption {
            type = lib.types.ints.between 1 50;
            default = 20;
            description = "Maximum % of RAM zswap may consume.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        swapDevices = [
          {
            device = cfg.swapfilePath;
            size = cfg.swapfileSizeMiB;
            priority = 0;
          }
        ];

        boot.kernelParams = [
          "zswap.enabled=1"
          "zswap.compressor=${cfg.zswap.compressor}"
          "zswap.zpool=${cfg.zswap.zpool}"
          "zswap.max_pool_percent=${toString cfg.zswap.maxPoolPercent}"
        ];

        # The chosen compressor/zpool must be present in the initrd or
        # zswap can fall back to the kernel default before stage-1 loads
        # extra modules.
        boot.initrd.kernelModules = [
          (compressorModule cfg.zswap.compressor)
          (zpoolModule cfg.zswap.zpool)
        ];
      };
    };
}
