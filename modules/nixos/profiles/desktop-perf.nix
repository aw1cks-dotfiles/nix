{ config, lib, ... }:
let
  inherit (config.aw1cks) modules;
in
{
  # High-performance desktop tuning bundle.
  #
  # Sibling profile to `desktop`. Hosts that want this stack import both
  # profiles directly:
  #   imports = [
  #     config.aw1cks.profiles.nixos.desktop
  #     config.aw1cks.profiles.nixos.desktop-perf
  #   ];
  #
  # Importing this profile == enabling the stack. Sub-options remain
  # available for fine-tuning:
  #   - aw1cks.cachyosKernel.*    (variant, lto, march)
  #   - aw1cks.scx.scheduler
  #   - aw1cks.zswapSwapfile.*    (path, size, compressor, etc.)
  #   - aw1cks.bpftune.*          (opt-in network-layer auto-tuning)
  #   - aw1cks.desktop.highPerf.* (amdPstate, mglru, damon, sysctls, etc.)
  #
  # Composition: this profile owns the cohesive desktop tuning (sysctls,
  # kernel params, gamemode/oomd/irqbalance, MGLRU, DAMON) and switches
  # on the atomic implementation modules (cachyos-kernel, scx,
  # zswap-swapfile) with opinionated default values that hosts can
  # override.
  aw1cks.profiles.nixos.desktop-perf =
    { config, lib, ... }:
    let
      cfg = config.aw1cks.desktop.highPerf;

      # Profile-opinion priority: tighter than lib.mkDefault (1000) so we
      # override nixpkgs/desktop-baseline defaults, but looser than
      # lib.mkForce (50) so hosts can still override with plain
      # assignment or lib.mkDefault. Conventional value is 500.
      mkProfile = lib.mkOverride 500;
    in
    {
      imports = [
        modules.nixos.cachyos-kernel
        modules.nixos.scx
        modules.nixos.zswap-swapfile
        modules.nixos.bpftune
      ];

      options.aw1cks.desktop.highPerf = {
        mitigationsOff = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Pass mitigations=off on the kernel command line. Acceptable on
            single-user machines that do not run untrusted code in
            browsers/sandboxes you care about. Set false to retain default
            CPU vulnerability mitigations.
          '';
        };

        amdPstate = lib.mkOption {
          type = lib.types.enum [
            "active"
            "guided"
            "passive"
            "disabled"
          ];
          default = "guided";
          description = ''
            amd_pstate driver mode. "guided" is recommended for Zen 3
            desktops. "disabled" leaves the kernel default.
          '';
        };

        gamemode.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Feral GameMode (per-process performance hints).";
        };

        oomd.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable systemd-oomd (userspace OOM handler).";
        };

        irqbalance.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the irqbalance daemon.";
        };

        bbr.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "TCP BBR congestion control + fq qdisc.";
        };

        mglru.minTtlMs = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 1000;
          description = ''
            MGLRU min_ttl_ms. Default upstream is 0 (no protection); 1000-2000
            reduces thrashing under memory pressure. Applied via tmpfiles.
          '';
        };

        damonReclaim = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable DAMON_RECLAIM proactive reclaim.";
          };

          minAgeSeconds = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 30;
            description = "Page out regions not accessed for this many seconds.";
          };

          quotaMiBPerSec = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 1024;
            description = "Reclaim speed cap, in MiB/s.";
          };

          wmarkHigh = lib.mkOption {
            type = lib.types.ints.between 0 1000;
            default = 500;
            description = "Disable DAMON_RECLAIM when free memory % * 10 above this.";
          };

          wmarkMid = lib.mkOption {
            type = lib.types.ints.between 0 1000;
            default = 400;
            description = "Activate DAMON_RECLAIM when free memory % * 10 below this.";
          };

          wmarkLow = lib.mkOption {
            type = lib.types.ints.between 0 1000;
            default = 200;
            description = "Stop DAMON_RECLAIM when free memory % * 10 falls below this.";
          };
        };

        extraSysctls = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.oneOf [
              lib.types.int
              lib.types.str
              lib.types.bool
            ]
          );
          default = { };
          description = ''
            Extra sysctls merged on top of the defaults. Use lib.mkForce
            to override a profile default entirely.
          '';
        };
      };

      config = {
        # Switch on the atomic modules. Defaults so per-host overrides
        # via plain assignment work without lib.mkForce.
        aw1cks.cachyosKernel.enable = lib.mkDefault true;
        aw1cks.scx.enable = lib.mkDefault true;
        aw1cks.zswapSwapfile.enable = lib.mkDefault true;

        boot.kernelParams =
          (lib.optional (cfg.amdPstate != "disabled") "amd_pstate=${cfg.amdPstate}")
          ++ (lib.optional cfg.mitigationsOff "mitigations=off")
          ++ [
            "split_lock_detect=off"
            "transparent_hugepage=madvise"
          ];

        boot.kernel.sysctl = lib.mkMerge [
          {
            # Memory: pair with zswap (high swappiness pushes more into compressed cache).
            "vm.swappiness" = mkProfile 100;
            "vm.vfs_cache_pressure" = mkProfile 50;
            "vm.dirty_ratio" = mkProfile 10;
            "vm.dirty_background_ratio" = mkProfile 5;
            # Overrides nixpkgs default of 1048576; max_map_count maximum
            # is 2147483642 and Wine/Proton/Star Citizen-class titles
            # benefit from the headroom.
            "vm.max_map_count" = mkProfile 2147483642;
            "vm.compaction_proactiveness" = mkProfile 20;
            "kernel.split_lock_mitigate" = mkProfile 0;
            # nixpkgs already defaults these to 524288 via lib.mkDefault.
            # Re-asserting at mkProfile priority means we win the tie if
            # upstream ever drops the value, while still letting hosts
            # override.
            "fs.inotify.max_user_watches" = mkProfile 524288;
            "fs.inotify.max_user_instances" = mkProfile 524288;
          }
          (lib.mkIf cfg.bbr.enable {
            "net.core.default_qdisc" = mkProfile "fq";
            "net.ipv4.tcp_congestion_control" = mkProfile "bbr";
          })
          cfg.extraSysctls
        ];

        # MGLRU min_ttl_ms via tmpfiles (no sysctl path for this knob).
        systemd.tmpfiles.rules = [
          "w- /sys/kernel/mm/lru_gen/min_ttl_ms - - - - ${toString cfg.mglru.minTtlMs}"
        ];

        # DAMON_RECLAIM: module parameters need ordered writes; oneshot service.
        systemd.services.damon-reclaim-tune = lib.mkIf cfg.damonReclaim.enable {
          description = "Configure DAMON_RECLAIM proactive reclaim";
          wantedBy = [ "multi-user.target" ];
          after = [ "sysinit.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script =
            let
              d = cfg.damonReclaim;
              p = "/sys/module/damon_reclaim/parameters";
              quotaBytes = toString (d.quotaMiBPerSec * 1024 * 1024);
              minAgeUs = toString (d.minAgeSeconds * 1000000);
            in
            ''
              if [ ! -d ${p} ]; then
                echo "DAMON_RECLAIM module not loaded; attempting modprobe" >&2
                /run/current-system/sw/bin/modprobe damon_reclaim || {
                  echo "damon_reclaim module unavailable; skipping" >&2
                  exit 0
                }
              fi
              echo ${minAgeUs}             > ${p}/min_age
              echo ${quotaBytes}           > ${p}/quota_sz
              echo 1000                    > ${p}/quota_reset_interval_ms
              echo ${toString d.wmarkHigh} > ${p}/wmarks_high
              echo ${toString d.wmarkMid}  > ${p}/wmarks_mid
              echo ${toString d.wmarkLow}  > ${p}/wmarks_low
              echo Y                       > ${p}/enabled
            '';
        };

        programs.gamemode.enable = lib.mkDefault cfg.gamemode.enable;
        systemd.oomd.enable = lib.mkDefault cfg.oomd.enable;
        services.irqbalance.enable = lib.mkDefault cfg.irqbalance.enable;

        # Avoid double-managing swap.
        zramSwap.enable = lib.mkDefault false;
      };
    };
}
