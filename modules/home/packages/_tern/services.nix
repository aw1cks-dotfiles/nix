{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tern;
  tern = config.modules.tern;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  enabled = cfg.daemon.enable || cfg.remote.enable;
  pluginRuntimePackages = lib.concatMap (plugin: plugin.runtimePackages) (
    builtins.attrValues (lib.filterAttrs (_: plugin: plugin.enable) tern.plugins)
  );
  absolutePath = lib.types.strMatching "/.*";
  mutablePath =
    path:
    lib.hasPrefix "/" path
    && path != builtins.storeDir
    && !(lib.hasPrefix "${builtins.storeDir}/" path)
    && !(builtins.elem ".." (lib.splitString "/" path));
  commonOptions = name: {
    enable = lib.mkEnableOption "the Home Manager Tern ${name} user service";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Start at login/user-manager startup. Disabling this leaves a manually
        startable unit. This module never stops or adopts native/installer jobs;
        explicitly retire those supervisors before enabling management.
      '';
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra service environment, overriding modules.tern.environment except
        TERN_CONFIG_DIR and TERN_DAEMON_SOCKET, which remain module-owned.
        Values enter the Nix store; use mutable files for secrets.
      '';
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional CLI arguments. Declared service flags, remote user mode and
        relay selection cannot be overridden here; use the typed options.
      '';
    };
    restartPolicy = lib.mkOption {
      type = lib.types.enum [
        "no"
        "on-failure"
        "always"
      ];
      default = if name == "session daemon" then "always" else "on-failure";
      description = ''
        Supervisor restart policy. The session daemon defaults to always so
        GUI clients can reconnect after an empty daemon's clean idle exit even
        with native supervision disabled. This never restarts running panes.
        Selecting on-failure permits native idle exit but requires an explicit
        managed-service restart afterwards; no second startup mechanism is added.
        The remote server defaults to on-failure.
        Changed executable, environment and socket settings take effect on the
        next natural start, not by killing running panes. systemd uses
        X-SwitchMethod=keep-old. Home Manager launchd still stops changed/removed
        plists: changing autostart/restart policy or disabling a service can end
        sessions.
      '';
    };
    restartDelay = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 5;
      description = "Restart delay in seconds (launchd ThrottleInterval or systemd RestartSec).";
    };
  };
  remoteArgs = [
    "remote"
    "serve"
    "--user"
    "--listen"
    "${cfg.remote.listenAddress}:${toString cfg.remote.port}"
    "--state-dir"
    cfg.remote.stateDirectory
    "--relay"
    (if cfg.remote.relay.enable then cfg.remote.relay.url else "none")
  ]
  ++ lib.optionals (cfg.remote.accessFile != null) [
    "--access"
    cfg.remote.accessFile
  ]
  ++ lib.optionals (cfg.remote.authorizedKeysFile != null) [
    "--authorized-keys"
    cfg.remote.authorizedKeysFile
  ]
  ++ lib.optionals (cfg.remote.relay.enable && cfg.remote.relay.caFile != null) [
    "--relay-ca"
    cfg.remote.relay.caFile
  ];
  serviceEnvironment =
    name:
    {
      HOME = config.home.homeDirectory;
    }
    // tern.environment
    // cfg.${name}.environment
    // {
      TERN_CONFIG_DIR = tern.configDirectory;
      TERN_DAEMON_SOCKET = tern.socket;
    };
  stateDirectory = name: if name == "remote" then cfg.remote.stateDirectory else tern.stateDirectory;
  runner =
    name:
    pkgs.writeShellApplication {
      name = "tern-${name}-managed";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        umask 077
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (key: value: "export ${key}=${lib.escapeShellArg value}") (
            serviceEnvironment name
          )
        )}
        # Environment overrides may replace PATH. Restore declared tools and the
        # managed profile CLI for plugins that invoke tern themselves.
        export PATH=${
          lib.escapeShellArg (
            lib.makeBinPath ([ pkgs.coreutils ] ++ pluginRuntimePackages ++ [ config.home.profileDirectory ])
          )
        }:"$PATH"
        ${lib.concatMapStringsSep "\n"
          (directory: ''
            directory=${lib.escapeShellArg directory}
            if [[ -L "$directory" || ( -e "$directory" && ( ! -d "$directory" || ! -O "$directory" ) ) ]]; then
              echo "Tern requires a user-owned, non-symlink private directory: $directory" >&2
              exit 1
            fi
            mkdir -p -- "$directory"
            chmod 700 -- "$directory"
          '')
          (
            lib.unique [
              tern.configDirectory
              (stateDirectory name)
            ]
          )
        }
        ${lib.optionalString (name == "daemon") ''
          mkdir -p -- ${lib.escapeShellArg (builtins.dirOf tern.socket)}
        ''}
        ${lib.optionalString isDarwin ''
          log=${lib.escapeShellArg "${stateDirectory name}/${name}.log"}
          if [[ -L "$log" || ( -e "$log" && ( ! -f "$log" || ! -O "$log" ) ) ]]; then
            echo "Tern log must be a user-owned regular file: $log" >&2
            exit 1
          fi
          touch -- "$log"
          chmod 600 -- "$log"
          exec >>"$log" 2>&1
        ''}
        exec ${
          lib.escapeShellArgs (
            [ tern.executable ]
            ++ (
              if name == "daemon" then
                [
                  "daemon"
                  "--socket"
                  tern.socket
                ]
              else
                remoteArgs
            )
            ++ cfg.${name}.extraArgs
          )
        }
      '';
    };
  # Stable paths keep ordinary executable/environment/socket changes out of the
  # launchd plist. Existing processes retain their old configuration until exit.
  runnerPath = name: "${config.home.profileDirectory}/bin/tern-${name}-managed";
  reservedArgs =
    name:
    if name == "daemon" then
      [
        "--socket"
        "--login"
      ]
    else
      [
        "--user"
        "--listen"
        "--state-dir"
        "--access"
        "--authorized-keys"
        "--relay"
        "--relay-ca"
      ];
  extraArgsValid =
    name:
    lib.all (
      arg:
      arg != "--" && !(lib.any (flag: arg == flag || lib.hasPrefix "${flag}=" arg) (reservedArgs name))
    ) cfg.${name}.extraArgs;
  serviceNames = lib.filter (name: cfg.${name}.enable) [
    "daemon"
    "remote"
  ];
in
{
  options.services.tern = {
    daemon = commonOptions "session daemon";
    remote = commonOptions "remote server" // {
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Listener address; explicitly select 0.0.0.0 or a host address for direct remote access. Bracket IPv6 addresses. No firewall rules are opened.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8376;
        description = "Remote QUIC listener port.";
      };
      stateDirectory = lib.mkOption {
        type = absolutePath;
        default = tern.stateDirectory;
        defaultText = lib.literalExpression "config.modules.tern.stateDirectory";
        description = "Mutable private remote state directory, preserved on activation and removal. Always served with --user, never system login mode.";
      };
      accessFile = lib.mkOption {
        type = lib.types.nullOr absolutePath;
        default = null;
        description = "Optional mutable access policy file passed with --access; contents are never copied into the store.";
      };
      authorizedKeysFile = lib.mkOption {
        type = lib.types.nullOr absolutePath;
        default = null;
        description = "Optional mutable authorized keys file passed with --authorized-keys; not generated or overwritten.";
      };
      relay = {
        enable = lib.mkEnableOption "the remote relay (disabled explicitly with --relay none by default)";
        url = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Explicit relay URL, required when relay.enable is true; no implicit upstream relay.";
        };
        caFile = lib.mkOption {
          type = lib.types.nullOr absolutePath;
          default = null;
          description = "Optional relay CA certificate file, passed with --relay-ca only when the relay is enabled.";
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf enabled {
      assertions = [
        {
          assertion = tern.enable;
          message = "services.tern requires modules.tern.enable = true.";
        }
        {
          assertion = isDarwin || isLinux;
          message = "services.tern supports only Darwin launchd and Linux systemd user services.";
        }
        {
          assertion = !isDarwin || config.launchd.enable;
          message = "services.tern requires launchd.enable on Darwin.";
        }
        {
          assertion =
            !cfg.remote.enable
            || !cfg.remote.relay.enable
            || (cfg.remote.relay.url != "" && cfg.remote.relay.url != "none");
          message = "services.tern.remote.relay.url must select an explicit relay when relay.enable is true.";
        }
      ]
      ++ lib.concatMap (name: [
        {
          assertion = mutablePath (stateDirectory name) && mutablePath tern.configDirectory;
          message = "services.tern.${name} state/config directories must be absolute mutable paths outside the Nix store without parent components.";
        }
        {
          assertion = lib.all (key: builtins.match "[a-zA-Z_][a-zA-Z0-9_]*" key != null) (
            lib.attrNames (serviceEnvironment name)
          );
          message = "services.tern.${name} environment names must be valid shell variable names.";
        }
        {
          assertion = extraArgsValid name;
          message = "services.tern.${name}.extraArgs must not override module-owned flags or contain --.";
        }
      ]) serviceNames;

      home.packages = map runner serviceNames;

      # Read-only migration guard: fail before links/units change, never unload a
      # native/installer supervisor or kill its processes. A loaded idle job can
      # also race a newly managed service, so check registration, not just PID.
      home.activation.checkTernSupervisors = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        ${lib.optionalString isDarwin ''
          for label in ${
            lib.escapeShellArgs (
              lib.optionals cfg.daemon.enable [
                "so.stencil.tern.daemon"
                "so.stencil.tern.login"
              ]
              ++ lib.optional cfg.remote.enable "so.stencil.tern.remote"
            )
          }; do
            for domain in "gui/$UID" "user/$UID" system; do
              if /bin/launchctl print "$domain/$label" >/dev/null 2>&1; then
                echo "Tern migration required: $domain/$label is loaded. Preserve/close sessions and explicitly retire the native/installer supervisor before enabling services.tern; no job was stopped." >&2
                exit 1
              fi
            done
          done
        ''}
        ${lib.optionalString isLinux ''
          runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
          for unit in ${
            lib.escapeShellArgs (
              lib.optional cfg.daemon.enable "tern-daemon.service"
              ++ lib.optional cfg.remote.enable "tern-remote.service"
            )
          }; do
            for scope in --user --system; do
              load_state=""
              if ! load_state=$(XDG_RUNTIME_DIR="$runtime_dir" ${lib.escapeShellArg config.systemd.user.systemctlPath} "$scope" show "$unit" --property=LoadState --value); then
                if [[ "$load_state" != not-found ]]; then
                  echo "Cannot inspect Tern supervisors ($scope $unit). Ensure the system/user manager is reachable; no service was changed." >&2
                  exit 1
                fi
              fi
              if [[ "$load_state" != not-found ]]; then
                echo "Tern migration required: $scope $unit has state $load_state. Preserve/close sessions and explicitly retire the installer supervisor before enabling services.tern; no unit was stopped." >&2
                exit 1
              fi
            done
          done
        ''}
      '';
    })
    (lib.mkIf (enabled && isDarwin) {
      launchd.agents = lib.genAttrs (map (name: "tern-${name}-managed") serviceNames) (
        unitName:
        let
          name = lib.removeSuffix "-managed" (lib.removePrefix "tern-" unitName);
          service = cfg.${name};
        in
        {
          enable = true;
          config = {
            ProgramArguments = [ (runnerPath name) ];
            RunAtLoad = service.autostart;
            KeepAlive =
              if service.restartPolicy == "no" then
                false
              else
                {
                  AfterInitialDemand = true;
                }
                // lib.optionalAttrs (service.restartPolicy == "on-failure") {
                  SuccessfulExit = false;
                }
                // lib.optionalAttrs (service.restartPolicy == "always") {
                  # An always-existing path requests restart for every exit status,
                  # while AfterInitialDemand still permits autostart = false.
                  PathState."/" = true;
                };
            ThrottleInterval = service.restartDelay;
            Umask = 63;
            # Pane processes must not be killed as a launchd process-group
            # cleanup side effect. Explicit daemon termination may still end them.
            AbandonProcessGroup = true;
          };
        }
      );
    })
    (lib.mkIf (enabled && isLinux) {
      systemd.user.services = lib.genAttrs (map (name: "tern-${name}-managed") serviceNames) (
        unitName:
        let
          name = lib.removeSuffix "-managed" (lib.removePrefix "tern-" unitName);
          service = cfg.${name};
        in
        {
          Unit = {
            Description = "Tern managed ${name} (user only)";
            X-SwitchMethod = "keep-old";
          };
          Service = {
            Type = "simple";
            ExecStart = lib.escapeShellArg (runnerPath name);
            Restart = service.restartPolicy;
            RestartSec = service.restartDelay;
            UMask = "0077";
            StandardOutput = "journal";
            StandardError = "journal";
            KillMode = "process";
          };
          Install.WantedBy = lib.optional service.autostart "default.target";
        }
      );
    })
  ];
}
