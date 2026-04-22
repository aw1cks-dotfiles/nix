{ ... }:
let
  validSchedulers = [
    "scx_lavd"
    "scx_bpfland"
    "scx_rusty"
    "scx_flash"
    "scx_rustland"
    "scx_p2dq"
    "scx_layered"
    "scx_simple"
    "scx_central"
  ];
in
{
  # SCX (sched-ext) userspace scheduler.
  # Owns the `aw1cks.scx.*` option surface.
  aw1cks.modules.nixos.scx =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.aw1cks.scx = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the SCX userspace scheduler.";
        };

        scheduler = lib.mkOption {
          type = lib.types.enum validSchedulers;
          default = "scx_lavd";
          description = ''
            SCX scheduler to load on boot.

            - scx_lavd: Latency-criticality Aware Virtual Deadline. Best
              general desktop/gaming choice; topology-aware (CCD-friendly).
            - scx_bpfland: vruntime-based with interactive prioritisation
              via voluntary context-switch rate. Strong mixed-load alt.
            - scx_rusty: Throughput-tuned. Best for CPU-bound batch.
          '';
        };
      };

      config = lib.mkIf config.aw1cks.scx.enable {
        services.scx = {
          enable = true;
          package = pkgs.scx.full;
          scheduler = config.aw1cks.scx.scheduler;
        };
      };
    };
}
