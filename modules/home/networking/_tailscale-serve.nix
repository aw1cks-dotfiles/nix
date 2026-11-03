{
  config,
  lib,
  pkgs,
  hostFacts,
  ...
}:
let
  cfg = config.services.tailscale-serve;
  host = lib.toLower (hostFacts.tailnetHost or "");
  labels = lib.splitString "." host;
  validHost =
    lib.hasSuffix ".ts.net" host
    && builtins.stringLength host <= 253
    && lib.all (
      label:
      builtins.stringLength label <= 63
      && builtins.match "[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?" label != null
    ) labels;
  routes = lib.mapAttrsToList (_: endpoint: {
    inherit (endpoint) httpsPort targetPort;
  }) (lib.filterAttrs (_: endpoint: endpoint.enable) cfg.endpoints);
  httpsPorts = map (route: route.httpsPort) routes;
  tool = import ../../integrations/_tailscale-serve-package.nix { inherit pkgs; };
  markerFile = "${config.xdg.stateHome}/tailscale-serve/managed.json";
  json = pkgs.formats.json { };
  rawConfig = json.generate "tailscale-serve-config.json" (
    if routes == [ ] then
      { }
    else
      {
        TCP = builtins.listToAttrs (
          map (route: lib.nameValuePair (toString route.httpsPort) { HTTPS = true; }) routes
        );
        Web = builtins.listToAttrs (
          map (
            route:
            lib.nameValuePair "${host}:${toString route.httpsPort}" {
              Handlers."/" = {
                Proxy = "http://127.0.0.1:${toString route.targetPort}";
              };
            }
          ) routes
        );
      }
  );
  emptyConfig = json.generate "tailscale-serve-empty-config.json" { };
  settingsFor =
    enabled: configFile:
    json.generate "tailscale-serve-settings.json" {
      tailscale = cfg.executable;
      hostname = host;
      inherit markerFile configFile enabled;
    };
  settings = settingsFor true rawConfig;
  cleanupSettings = settingsFor false emptyConfig;
  runner = pkgs.writeShellApplication {
    name = "tailscale-serve-managed";
    text = ''
      exec ${lib.getExe tool} ${settings}
    '';
  };
  systemctl = ''env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${lib.escapeShellArg config.systemd.user.systemctlPath} --user'';
in
{
  options.services.tailscale-serve = {
    enable = lib.mkEnableOption "declarative authoritative private Tailscale Serve configuration";
    executable = lib.mkOption {
      type = lib.types.str;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        else
          "${pkgs.tailscale}/bin/tailscale";
      defaultText = lib.literalExpression ''the Tailscale.app CLI on Darwin, or "''${pkgs.tailscale}/bin/tailscale" on Linux'';
      description = ''
        Absolute path to the existing Tailscale CLI, which must support
        `serve set-raw` with a complete ServeConfig on standard input. This module
        replaces the complete Serve configuration and never installs or replaces
        the daemon. On Linux the user must already be authorized as a Tailscale
        operator; the user service never elevates privileges.
      '';
    };
    endpoints = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to include this endpoint in the managed Serve roots.";
            };
            httpsPort = lib.mkOption {
              type = lib.types.port;
              description = "Private HTTPS listener port for this root handler.";
            };
            targetPort = lib.mkOption {
              type = lib.types.port;
              description = "Loopback HTTP target port for this root handler.";
            };
          };
        }
      );
      default = { };
      description = ''
        Named private HTTPS root handlers proxying to HTTP on 127.0.0.1.
        Enabled endpoints must use distinct HTTPS ports. Registering an endpoint
        does not enable management. When enabled, this registry is authoritative
        for the complete Serve configuration; undeclared Serve state is removed.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.hasPrefix "/" cfg.executable;
          message = "services.tailscale-serve.executable must be an absolute CLI path.";
        }
        {
          assertion =
            lib.hasPrefix "/" markerFile
            && markerFile != builtins.storeDir
            && !(lib.hasPrefix "${builtins.storeDir}/" markerFile)
            && !(builtins.elem ".." (lib.splitString "/" markerFile));
          message = "services.tailscale-serve requires an absolute XDG state path outside the Nix store, without parent-directory components.";
        }
      ];

      # Run after Home Manager removes obsolete jobs. Explicitly stop any job
      # still loaded (including systemd's suggest-only activation mode) before
      # cleanup, so a periodic apply cannot recreate the managed configuration.
      home.activation.cleanupTailscaleServe = lib.mkIf (!cfg.enable) (
        lib.hm.dag.entryAfter
          (
            [
              "writeBoundary"
              "linkGeneration"
            ]
            ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin "setupLaunchAgents"
            ++ lib.optional pkgs.stdenv.hostPlatform.isLinux "reloadSystemd"
          )
          ''
              ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                if /bin/launchctl print "gui/$UID/org.nix-community.home.tailscale-serve" >/dev/null 2>&1; then
                  run /bin/launchctl bootout "gui/$UID/org.nix-community.home.tailscale-serve"
                  if [[ -z "''${DRY_RUN_CMD:-}" ]]; then
                    for ((attempt = 0; attempt < 30; attempt++)); do
                      if ! /bin/launchctl print "gui/$UID/org.nix-community.home.tailscale-serve" >/dev/null 2>&1; then
                        break
                      fi
                      /bin/sleep 1
                    done
                    if /bin/launchctl print "gui/$UID/org.nix-community.home.tailscale-serve" >/dev/null 2>&1; then
                      echo "Tailscale Serve controller did not stop; refusing cleanup while it may still write." >&2
                      exit 1
                    fi
                  fi
                fi
              ''}
              ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                if ${systemctl} show-environment >/dev/null 2>&1; then
                  for unit in tailscale-serve.timer tailscale-serve.service; do
                    loadState=$(${systemctl} show --property=LoadState --value "$unit")
                    activeState=$(${systemctl} show --property=ActiveState --value "$unit")
                    if [[ "$loadState" != "not-found" || "$activeState" != "inactive" ]]; then
                      run ${systemctl} stop "$unit"
                    fi
                  done
                  unset loadState activeState unit
                else
                  verboseEcho "No systemd user manager; clearing managed Serve configuration directly."
                fi
              ''}
            if [[ -e ${lib.escapeShellArg markerFile} || -L ${lib.escapeShellArg markerFile} ]]; then
              if ! run ${lib.getExe tool} ${cleanupSettings}; then
                echo ${lib.escapeShellArg "Tailscale Serve cleanup failed; activation marker is retained at ${markerFile}. Restore Tailscale connectivity/operator access and rerun Home Manager activation, or run ${lib.getExe tool} ${cleanupSettings}."} >&2
                exit 1
              fi
            fi
          ''
      );
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = pkgs.stdenv.hostPlatform.isDarwin || pkgs.stdenv.hostPlatform.isLinux;
          message = "services.tailscale-serve requires Darwin launchd or Linux systemd user services.";
        }
        {
          assertion = validHost;
          message = "services.tailscale-serve requires hostFacts.tailnetHost to be the full Tailscale DNS hostname without a trailing dot.";
        }
        {
          assertion = lib.all (route: route.httpsPort > 0 && route.targetPort > 0) routes;
          message = "services.tailscale-serve requires positive HTTPS and target ports.";
        }
        {
          assertion = builtins.length httpsPorts == builtins.length (lib.unique httpsPorts);
          message = "services.tailscale-serve requires distinct HTTPS ports across all enabled endpoints.";
        }
      ];
      home.packages = [
        tool
        runner
      ];
      launchd.agents.tailscale-serve = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = true;
        config = {
          ProgramArguments = [ (lib.getExe runner) ];
          RunAtLoad = true;
          StartInterval = 60;
          StandardOutPath = "${config.home.homeDirectory}/.tailscale-serve.log";
          StandardErrorPath = "${config.home.homeDirectory}/.tailscale-serve.log";
        };
      };
      systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        services.tailscale-serve = {
          Unit.Description = "Apply authoritative private Tailscale Serve configuration";
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe runner;
            UMask = "0077";
          };
        };
        timers.tailscale-serve = {
          Unit.Description = "Periodically apply authoritative private Tailscale Serve configuration";
          Timer = {
            OnStartupSec = "1s";
            OnUnitInactiveSec = "60s";
            Unit = "tailscale-serve.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    })
  ];
}
