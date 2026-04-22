{ ... }:
{
  # Narrow bpftune wrapper for network-layer tuning only.
  #
  # Intentionally excludes tcp_conn_tuner so static qdisc/congestion-control
  # policy remains authoritative.
  aw1cks.modules.nixos.bpftune =
    {
      config,
      lib,
      utils,
      ...
    }:
    let
      cfg = config.aw1cks.bpftune;
    in
    {
      options.aw1cks.bpftune = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable bpftune as a network-layer tuning adjunct. This wrapper only
            allows the explicitly listed network-oriented tuners and keeps
            congestion-control selection out of bpftune.
          '';
        };

        tuners = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "ip_frag_tuner.so"
              "netns_tuner.so"
              "sysctl_tuner.so"
              "tcp_buffer_tuner.so"
              "udp_buffer_tuner.so"
              "net_buffer_tuner.so"
            ]
          );
          default = [
            "ip_frag_tuner.so"
            "netns_tuner.so"
            "sysctl_tuner.so"
            "tcp_buffer_tuner.so"
            "udp_buffer_tuner.so"
            "net_buffer_tuner.so"
          ];
          description = ''
            bpftune plugins to allow. The default set stays narrowly scoped to
            network-layer tuning and deliberately excludes tcp_conn_tuner.so so
            bpftune does not manage congestion control.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.tuners != [ ];
            message = "aw1cks.bpftune.enable requires at least one allowed bpftune tuner.";
          }
        ];

        services.bpftune.enable = true;

        systemd.services.bpftune.serviceConfig.ExecStart = lib.mkForce [
          ""
          (
            utils.escapeSystemdExecArgs (
              [ (lib.getExe config.services.bpftune.package) ]
              ++ lib.concatMap (tuner: [ "-a" tuner ]) cfg.tuners
            )
          )
        ];
      };
    };
}
