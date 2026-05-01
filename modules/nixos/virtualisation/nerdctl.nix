{ ... }:

{
  aw1cks.modules.nixos.nerdctl =
    { lib, config, pkgs, ... }:
    let
      nerdctlBin = "${pkgs.nerdctl}/bin/nerdctl";
      containerdSock = "unix:///run/containerd/containerd.sock";

      # Wrapper: transparent sudo escalation for wheel users.
      #
      # nerdctl's rootless detection is purely UID-based (os.Geteuid() != 0).
      # There is no flag, env var, or config option that suppresses the rootless
      # re-exec path when running as a non-root user. The only correct approach
      # without patching nerdctl is to run it as root.
      #
      # This wrapper calls sudo nerdctl when invoked by a non-root user.
      # The sudoers rule below grants NOPASSWD for wheel users so this is
      # transparent. Environment is preserved (-E) so user shell env vars work.
      nerdctlWrapper = pkgs.writeShellScriptBin "nerdctl" ''
        if [ "$(id -u)" -eq 0 ]; then
          exec ${nerdctlBin} "$@"
        else
          exec sudo -E ${nerdctlBin} "$@"
        fi
      '';

      dockerWrapper = pkgs.writeShellScriptBin "docker" ''
        exec ${nerdctlWrapper}/bin/nerdctl "$@"
      '';
    in
    {
      boot.kernelModules = [ "erofs" ];

      # Enable cross-arch support via QEMU emulators.
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];
        # Required for emulators to work inside containers (sets the 'F' flag).
        preferStaticEmulators = true;
      };

      # Configure the system containerd with the EROFS snapshotter and differ.
      #
      # nerdctl talks directly to containerd via its task API (the same path as
      # `ctr`), so the mount manager is invoked correctly and the EROFS
      # snapshotter works. This is the key difference from Docker/moby, which
      # calls mount.All() directly and bypasses the mount manager entirely.
      #
      # Requirements:
      #   - containerd 2.2.3+ (promoted from unstable in pkgs overlay)
      #   - erofs-utils 1.8.2+ (nixpkgs ships 1.9.1; --sort=none requires 1.8.2+)
      #   - Linux kernel 5.16+ with the erofs module loaded
      virtualisation.containerd = {
        enable = true;
        settings = {
          version = 2;
          plugins = {
            "io.containerd.snapshotter.v1.erofs" = {
              ovl_mount_options = [ ];
            };
            # Use the EROFS differ first, falling back to the walking differ.
            # The EROFS differ converts OCI layers directly to EROFS blobs (faster
            # than the walking differ, which converts them on Commit).
            "io.containerd.service.v1.diff-service".default = [
              "erofs"
              "walking"
            ];
            # erofs-utils 1.8.2+ supports --sort=none to avoid reordering tar data.
            "io.containerd.differ.v1.erofs".mkfs_options = [
              "-T0"
              "--mkfs-time"
              "--sort=none"
            ];
          };
        };
      };

      # The nixpkgs containerd module has a fixed PATH ([containerd, runc, iptables]).
      # The EROFS differ plugin probes for mkfs.erofs at startup and skips itself
      # if the binary is not found. Extend containerd's service PATH with erofs-utils
      # so that mkfs.erofs is available when containerd loads its plugins.
      systemd.services.containerd.path = [ pkgs.erofs-utils ];

      # The nixpkgs containerd module creates the socket as root:root 0660.
      # Override the group to wheel so that sudoers rule grants can reach the
      # system containerd socket without a second privilege escalation.
      # ExecStartPost runs after containerd signals readiness (Type=notify),
      # so the socket exists by the time chgrp runs.
      systemd.services.containerd.serviceConfig.ExecStartPost =
        "${pkgs.coreutils}/bin/chgrp wheel /run/containerd/containerd.sock";

      # BuildKit daemon with containerd worker.
      #
      # nerdctl build delegates to buildkitd. Using the containerd worker
      # (rather than the OCI worker) lets buildkitd share the containerd image
      # store, so images built with `nerdctl build` are immediately available
      # to `nerdctl run` without a separate push/pull step.
      #
      # The namespace must match nerdctl's default namespace ("default") so
      # that images are visible across both tools.
      systemd.services.buildkitd = {
        description = "BuildKit daemon (containerd worker)";
        wantedBy = [ "multi-user.target" ];
        after = [ "containerd.service" ];
        requires = [ "containerd.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.buildkit}/bin/buildkitd --config=/etc/buildkit/buildkitd.toml";
          Delegate = "yes";
          KillMode = "process";
          Type = "notify";
          Restart = "always";
          RestartSec = "10";
        };
      };

      environment.etc."buildkit/buildkitd.toml".text = ''
        [worker.oci]
          enabled = false

        [worker.containerd]
          enabled = true
          namespace = "default"
          snapshotter = "erofs"
      '';

      # CNI network configuration for nerdctl's default bridge network.
      #
      # nerdctl's default network is named "bridge" (pkg/netutil/netutil_unix.go:
      # DefaultNetworkName = "bridge"). nerdctl writes and looks for its managed
      # config at a fixed path: /etc/cni/net.d/nerdctl-bridge.conflist
      # (getConfigPathForNetworkName returns "nerdctl-" + name + ".conflist").
      #
      # By providing this file via environment.etc, the NixOS activation puts a
      # read-only symlink at that path. nerdctl's fsExists() finds it and skips
      # creating a new default network — so the auto-generated conflist with the
      # firewall + tuning plugins is never written.
      #
      # The content mimics what nerdctl would generate (same nerdctlID hash,
      # same nerdctlLabels with nerdctl/default-network=true) but omits the
      # firewall and tuning plugins, which both require iptables and conflict
      # with the host nftables firewall. IP masquerading is handled by the
      # bridge plugin's ipMasq flag via the kernel NAT, not iptables.
      #
      # nerdctlID = sha256("bridge") in hex — computed once, stable forever.
      environment.etc."cni/net.d/nerdctl-bridge.conflist".text = builtins.toJSON {
        cniVersion = "1.0.0";
        name = "bridge";
        nerdctlID = "17f29b073143d8cd97b5bbe492bdeffec1c5fee55cc1fe2112c8b9335f8b6121";
        nerdctlLabels = { "nerdctl/default-network" = "true"; };
        plugins = [
          {
            type = "bridge";
            bridge = "nerdctl0";
            isGateway = true;
            ipMasq = true;
            hairpinMode = true;
            ipam = {
              type = "host-local";
              ranges = [ [ { subnet = "172.20.0.0/16"; gateway = "172.20.0.1"; } ] ];
              routes = [ { dst = "0.0.0.0/0"; } ];
            };
          }
          { type = "portmap"; capabilities = { portMappings = true; }; }
        ];
      };

      # System-wide nerdctl config used when nerdctl runs as root (e.g. via sudo).
      # This points nerdctl at the system containerd socket and sets the EROFS
      # snapshotter. The wrapper script below invokes nerdctl via `sudo -E`,
      # so NERDCTL_TOML in the user environment is forwarded to the root process.
      environment.etc."nerdctl/nerdctl.toml".text = ''
        address     = "${containerdSock}"
        namespace   = "default"
        snapshotter = "erofs"
      '';

      environment.variables.NERDCTL_TOML = "/etc/nerdctl/nerdctl.toml";

      # Allow wheel users to run nerdctl as root without a password.
      # This powers the transparent `sudo -E nerdctl` in the wrapper above.
      # NOPASSWD makes the escalation invisible to the user.
      # The SETENV tag preserves NERDCTL_TOML and other relevant env vars
      # forwarded by `sudo -E`.
      security.sudo.extraRules = [
        {
          groups = [ "wheel" ];
          commands = [
            {
              command = nerdctlBin;
              options = [ "NOPASSWD" "SETENV" ];
            }
          ];
        }
      ];

      environment.systemPackages = [
        nerdctlWrapper
        dockerWrapper
        pkgs.crun
        pkgs.erofs-utils
        pkgs.nftables
      ];
    };
}
