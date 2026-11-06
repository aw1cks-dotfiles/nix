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
    inherit (cfg) stateDirectory passwordFile port;
    tailnetHost = host;
    pluginDirectory = "${cfg.ompPluginPackage}/share/paseo-omp";
    configModule = "${cfg.package}/lib/paseo/packages/server/dist/server/server/config.js";
    instanceModule = "${cfg.package}/lib/paseo/packages/server/dist/server/server/daemon-instance.js";
  };
  withPassword = import ../../integrations/_paseo-with-password.nix { inherit pkgs; };
  runner = pkgs.writeShellApplication {
    name = "paseo-managed";
    runtimeInputs = [
      pkgs.nodejs_22
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
      # Authentication is loaded from private writable storage immediately before exec.
      node ${./files/paseo/prepare.mjs} ${settings}
      # Direct supervisor startup takes the PID lock atomically and fails on a
      # competing instance, rather than silently adopting daemon run's existing one.
      exec ${lib.getExe withPassword} ${lib.escapeShellArg cfg.passwordFile} ${cfg.package}/bin/paseo-server
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
