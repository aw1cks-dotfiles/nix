{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  cfg = config.services.kata;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  mutablePath =
    path:
    lib.hasPrefix "/" path
    && path != "/"
    && path != builtins.storeDir
    && !(lib.hasPrefix "${builtins.storeDir}/" path)
    && !(builtins.elem ".." (lib.splitString "/" path));
  connection = import ./connection.nix {
    inherit (cfg) stateDirectory listenAddress port;
  };
  inherit (connection) endpoint;
  clientEnvironment = connection.environment;
  client = pkgs.writeShellScriptBin "kata" ''
    ${lib.toShellVars clientEnvironment}
    export ${lib.concatStringsSep " " (builtins.attrNames clientEnvironment)}
    exec ${lib.escapeShellArg (lib.getExe cfg.package)} "$@"
  '';
  serviceEnvironment = clientEnvironment // {
    HOME = config.home.homeDirectory;
    KATA_SERVER = "";
    KATA_AUTOSTART_IDLE_TIMEOUT = "0";
    KATA_MCP_ENABLED = "false";
  };
  runner = pkgs.writeShellApplication {
    name = "kata-daemon-managed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      umask 077
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (key: value: "export ${key}=${lib.escapeShellArg value}") serviceEnvironment
      )}
      export PATH=${
        lib.escapeShellArg (
          lib.makeBinPath [
            config.home.profileDirectory
            pkgs.coreutils
          ]
        )
      }:"$PATH"
      ${lib.getExe pkgs.python3} ${./prepare-state.py} --state ${lib.escapeShellArg cfg.stateDirectory}${lib.optionalString isDarwin " --log"}
      ${lib.optionalString isDarwin ''
        exec >>${lib.escapeShellArg "${cfg.stateDirectory}/daemon.log"} 2>&1
      ''}
      exec ${
        lib.escapeShellArgs [
          (lib.getExe cfg.package)
          "daemon"
          "start"
          "--foreground"
          "--listen"
          endpoint
        ]
      }
    '';
  };
  # Keep the unit stable across rebuilds: upgrading a database-owning daemon
  # requires an explicit stop, backup, and restart rather than an implicit switch.
  runnerPath = "${config.home.profileDirectory}/bin/kata-daemon-managed";
in
{
  options.services.kata = {
    enable = lib.mkEnableOption "the independent managed local Kata daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = import ./package.nix { inherit pkgs; };
      defaultText = lib.literalExpression "import ./package.nix { inherit pkgs; }";
      description = "Native Kata package used by the daemon and shared clients.";
    };
    stateDirectory = lib.mkOption {
      type = lib.types.addCheck lib.types.str mutablePath;
      default = "${config.xdg.stateHome}/kata";
      defaultText = lib.literalExpression ''config.xdg.stateHome + "/kata"'';
      description = "Absolute mutable private state directory outside the Nix store, without parent components. Preserved when disabled.";
    };
    listenAddress = lib.mkOption {
      type = lib.types.enum [
        "127.0.0.1"
        "::1"
      ];
      default = "127.0.0.1";
      description = "Loopback-only TCP listener address.";
    };
    port = lib.mkOption {
      type = lib.types.addCheck lib.types.port (port: port > 0);
      default = 7777;
      description = "Fixed TCP port shared by the daemon and clients (not zero).";
    };
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start at user login; when false, retain the service for explicit starts.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable (
      {
        assertions = [
          {
            assertion = isDarwin || isLinux;
            message = "services.kata supports only Darwin launchd and Linux systemd user services.";
          }
          {
            assertion = !isDarwin || config.launchd.enable;
            message = "services.kata requires launchd.enable on Darwin.";
          }
        ];
        home.packages = [
          client
          runner
        ];
        home.sessionVariables = clientEnvironment;
      }
      // lib.optionalAttrs (lib.hasAttrByPath [ "modules" "tern" "environment" ] options) {
        # Do not require Tern, enable it, or supervise its kata plugin worker.
        modules.tern.environment = clientEnvironment;
      }
    ))
    (lib.mkIf (cfg.enable && isDarwin) {
      launchd.agents.kata-managed = {
        enable = true;
        config = {
          ProgramArguments = [ runnerPath ];
          RunAtLoad = cfg.autostart;
          KeepAlive = {
            AfterInitialDemand = true;
            SuccessfulExit = false;
          };
          ThrottleInterval = 5;
          Umask = 63;
          ExitTimeOut = 45;
        };
      };
    })
    (lib.mkIf (cfg.enable && isLinux) {
      systemd.user.services.kata-managed = {
        Unit = {
          Description = "Kata managed local daemon";
          X-SwitchMethod = "keep-old";
        };
        Service = {
          Type = "simple";
          ExecStart = lib.escapeShellArg runnerPath;
          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStopSec = 45;
          UMask = "0077";
          StandardOutput = "journal";
          StandardError = "journal";
        };
        Install.WantedBy = lib.optional cfg.autostart "default.target";
      };
    })
  ];
}
