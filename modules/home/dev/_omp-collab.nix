{ inputs }:
{
  config,
  lib,
  pkgs,
  hostFacts,
  ...
}:
let
  cfg = config.modules.ai.omp.collab;
  host = hostFacts.tailnetHost or "";
  labels = lib.splitString "." host;
  validHost =
    host != ""
    && builtins.stringLength host <= 253
    && lib.all (
      label:
      builtins.stringLength label <= 63
      && builtins.match "[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?" label != null
    ) labels;
  ports = [
    cfg.webPort
    cfg.relayPort
    cfg.webHttpsPort
    cfg.relayHttpsPort
  ];
  webUrl =
    "https://${host}" + lib.optionalString (cfg.webHttpsPort != 443) ":${toString cfg.webHttpsPort}";
  relayUrl = "wss://${host}:${toString cfg.relayHttpsPort}";
  command = name: port: [
    "${cfg.package}/bin/omp-collab-${name}"
    "--port"
    (toString port)
  ];
  launchAgent = name: port: {
    enable = true;
    config = {
      ProgramArguments = command name port;
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 5;
      # The home directory already exists when launchd loads the agent.
      # Avoid log subdirectories that may not exist at first activation.
      StandardOutPath = "${config.home.homeDirectory}/.omp-collab-${name}.log";
      StandardErrorPath = "${config.home.homeDirectory}/.omp-collab-${name}.log";
    };
  };
  systemdService = name: port: {
    Unit.Description = "OMP collab ${name}";
    Service = {
      ExecStart = lib.escapeShellArgs (command name port);
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isDarwin || pkgs.stdenv.hostPlatform.isLinux;
        message = "modules.ai.omp.collab requires Darwin launchd or Linux systemd user services.";
      }
      {
        assertion = validHost;
        message = "modules.ai.omp.collab requires hostFacts.tailnetHost to be a nonempty DNS hostname without a scheme, port, path, or trailing dot.";
      }
      {
        assertion = lib.all (port: port > 0) ports;
        message = "modules.ai.omp.collab ports must be between 1 and 65535; port 0 cannot be used for stable endpoints.";
      }
      {
        assertion = cfg.webPort != cfg.relayPort && cfg.webHttpsPort != cfg.relayHttpsPort;
        message = "modules.ai.omp.collab needs distinct web/relay loopback ports and distinct web/relay HTTPS ports.";
      }
    ];

    home.packages = [ cfg.package ];

    programs.omp = {
      enable = true;
      settings.collab = {
        webUrl = lib.mkDefault webUrl;
        relayUrl = lib.mkDefault relayUrl;
        autoStart = lib.mkDefault cfg.autoStart;
      };
    };

    launchd.agents = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      omp-collab-web = launchAgent "web" cfg.webPort;
      omp-collab-relay = launchAgent "relay" cfg.relayPort;
    };

    systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      omp-collab-web = systemdService "web" cfg.webPort;
      omp-collab-relay = systemdService "relay" cfg.relayPort;
    };
  };
}
