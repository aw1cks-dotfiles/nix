{ inputs }:
{
  config,
  lib,
  pkgs,
  hostFacts,
  ...
}:
let
  cfg = config.modules.ai.paseo;
  collab = config.modules.ai.omp.collab;
  host = hostFacts.tailnetHost or "";
  settings = (pkgs.formats.json { }).generate "paseo-managed.json" {
    version = 1;
    daemon = {
      listen = "127.0.0.1:${toString cfg.port}";
      hostnames = [ host ];
      relay.enabled = false;
    };
    pluginsEnabled = true;
    plugins.paseo-omp = {
      source = "directory";
      path = "${cfg.ompPluginPackage}/share/paseo-omp";
      enabled = true;
    };
  };
  runner = pkgs.writeShellApplication {
    name = "paseo-managed";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.openssl
      cfg.package
      config.programs.omp.package
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      umask 077
      export HOME=${lib.escapeShellArg config.home.homeDirectory}
      export PASEO_HOME=${lib.escapeShellArg cfg.stateDirectory}
      export PATH="$PATH:${config.home.profileDirectory}/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      export OMP_COMMAND=${lib.escapeShellArg (lib.getExe config.programs.omp.package)}
      export PI_CODING_AGENT_DIR="$HOME/.omp/agent"
      export PASEO_LISTEN=127.0.0.1:${toString cfg.port}
      export PASEO_HOSTNAMES=${lib.escapeShellArg host}
      export PASEO_RELAY_ENABLED=false
      # Suppress optional public service-proxy listeners from old user config.
      export PASEO_SERVICE_PROXY_ENABLED=false
      export PASEO_LOCAL_SPEECH_AUTO_DOWNLOAD=0
      unset PASEO_PASSWORD
      status=$(paseo daemon status --home "$PASEO_HOME" --json)
      if [[ $(jq -r '.localDaemon' <<< "$status") != stopped ]]; then
        echo "Paseo is already running; stop it before managed startup." >&2
        exit 1
      fi
      mkdir -p -- "$PASEO_HOME"
      if [[ -L "$PASEO_HOME" || ! -O "$PASEO_HOME" ]]; then
        echo "Paseo state must be a user-owned directory: $PASEO_HOME" >&2
        exit 1
      fi
      chmod 700 -- "$PASEO_HOME"
      config_file="$PASEO_HOME/config.json"
      existing_config='{}'
      if [[ -e "$config_file" || -L "$config_file" ]]; then
        existing_config=$(cat -- "$config_file")
      fi
      password_file=${lib.escapeShellArg cfg.passwordFile}
      if [[ ! -e "$password_file" && ! -L "$password_file" ]]; then
        if jq -e '.daemon.auth.password // false' <<< "$existing_config" >/dev/null; then
          echo "Provision passwordFile with the existing Paseo password before adoption." >&2
          exit 1
        fi
        mkdir -p -- "$(dirname -- "$password_file")"
        (set -o noclobber; openssl rand -hex 32 > "$password_file")
      fi
      if [[ ! -f "$password_file" || -L "$password_file" || ! -O "$password_file" ]]; then
        echo "Paseo password must be a private, user-owned regular file: $password_file" >&2
        exit 1
      fi
      mode=$(stat -c %a -- "$password_file")
      if (( (8#$mode & 077) != 0 )); then
        echo "Paseo password must not be group/world accessible: $password_file" >&2
        exit 1
      fi
      PASEO_PASSWORD=$(< "$password_file")
      if [[ "$PASEO_PASSWORD" != *[![:space:]]* || "$PASEO_PASSWORD" == *$'\n'* || "$PASEO_PASSWORD" == *$'\r'* ]]; then
        echo "Paseo password must contain one nonempty line: $password_file" >&2
        exit 1
      fi
      temporary=$(mktemp "$PASEO_HOME/config.json.XXXXXX")
      trap 'rm -f -- "$temporary"' EXIT
      jq --slurpfile managed ${settings} \
        '. * ($managed[0] | del(.plugins)) | .plugins += $managed[0].plugins' \
        <<< "$existing_config" > "$temporary"
      mv -f -- "$temporary" "$config_file"
      trap - EXIT
      export PASEO_PASSWORD
      # The native supervisor takes the PID lock atomically; never adopt another instance.
      exec ${cfg.package}/bin/paseo-server
    '';
  };
in
{
  options.modules.ai.paseo = {
    enable = lib.mkEnableOption "the authenticated, tailnet-only Paseo daemon with OMP Plugin";
    package = lib.mkOption {
      type = lib.types.package;
      default = import ../../integrations/_paseo-package.nix {
        inherit pkgs;
        paseoInput = inputs.paseo;
      };
      defaultText = lib.literalExpression "the pinned inputs.paseo package";
      description = "Nix-native Paseo daemon and CLI, including its plugin compiler runtime.";
    };
    ompPluginPackage = lib.mkOption {
      type = lib.types.package;
      default = import ../../integrations/_paseo-omp-package.nix { inherit pkgs; };
      defaultText = lib.literalExpression "the pinned OMP Plugin package";
      description = "Offline-prepared OMP Plugin registered from share/paseo-omp.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Loopback-only daemon port; never opened in the firewall.";
    };
    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 9443;
      description = "Private HTTPS port published by services.tailscale-serve when enabled.";
    };
    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.paseo";
      description = "Persistent private Paseo home outside the Nix store; never replaced or removed on switch.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/paseo/password";
      description = ''
        Private user-owned regular plaintext password file outside the Nix store.
        The service creates it once with a random password and mode 0600 if missing,
        preserves it across rebuilds, and refuses empty or group/world-readable files.
        Loaded as PASEO_PASSWORD at startup; inherited by daemon child processes.
        Read this file locally to enter the password in the phone app.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isDarwin || pkgs.stdenv.hostPlatform.isLinux;
        message = "modules.ai.paseo requires launchd or systemd user services.";
      }
      {
        assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9.-]*\\.ts\\.net" host != null;
        message = "modules.ai.paseo requires hostFacts.tailnetHost to be the full Tailscale HTTPS hostname.";
      }
      {
        assertion = cfg.port > 0 && cfg.httpsPort > 0;
        message = "modules.ai.paseo ports must be nonzero stable ports.";
      }
      {
        assertion =
          !collab.enable
          || !(builtins.elem cfg.port [
            collab.webPort
            collab.relayPort
          ]);
        message = "Paseo must use a different loopback port from OMP collab.";
      }
      {
        assertion =
          lib.hasPrefix "/" cfg.stateDirectory
          && lib.hasPrefix "/" cfg.passwordFile
          && !(lib.hasPrefix "/nix/store/" cfg.stateDirectory)
          && !(lib.hasPrefix "/nix/store/" cfg.passwordFile);
        message = "Paseo stateDirectory and passwordFile must be absolute paths outside the Nix store.";
      }
      {
        assertion = config.programs.omp.enable;
        message = "Paseo's OMP Plugin requires the existing Nix-managed programs.omp to be enabled.";
      }
    ];
    services.tailscale-serve.endpoints.paseo = {
      httpsPort = cfg.httpsPort;
      targetPort = cfg.port;
    };
    home.packages = [
      cfg.package
      cfg.ompPluginPackage
      runner
    ];
    launchd.agents.paseo = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe runner) ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        StandardOutPath = "${config.home.homeDirectory}/.paseo-service.log";
        StandardErrorPath = "${config.home.homeDirectory}/.paseo-service.log";
      };
    };
    systemd.user.services.paseo = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Authenticated private Paseo daemon";
      Service = {
        ExecStart = lib.getExe runner;
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
