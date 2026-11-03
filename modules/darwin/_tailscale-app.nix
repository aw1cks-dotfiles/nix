{
  config,
  lib,
  pkgs,
  hostFacts,
  ...
}:
let
  cfg = config.services.tailscale-app;
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  hostname = hostFacts.hostName or "";
  tailnetHost = lib.toLower (hostFacts.tailnetHost or "");
  tailnetDomain = lib.concatStringsSep "." (lib.tail (lib.splitString "." tailnetHost));
  cli = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
  arguments = [
    "--hostname=${hostname}"
    "--accept-dns=${lib.boolToString cfg.acceptDNS}"
    "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
    "--shields-up=${lib.boolToString cfg.shieldsUp}"
    "--auto-update=${lib.boolToString cfg.autoUpdate}"
    "--update-check=${lib.boolToString cfg.checkForUpdates}"
  ];
  apply = pkgs.writeShellApplication {
    name = "tailscale-app-preferences";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      # Login agents can start before the app's network extension is ready.
      ready=false
      for ((attempt = 0; attempt < 30; attempt++)); do
        if status=$(${lib.escapeShellArg cli} status --json) &&
          jq -e '.BackendState == "Running"' >/dev/null <<< "$status"; then
          ready=true
          break
        fi
        sleep 2
      done
      if [[ "$ready" != true ]]; then
        echo "Tailscale.app is not connected. Open it, approve/sign in as needed, then rerun tailscale-app-preferences." >&2
        exit 1
      fi
      if ! jq -e --arg domain ${lib.escapeShellArg tailnetDomain} \
        '(.CurrentTailnet.MagicDNSSuffix | ascii_downcase) == $domain' >/dev/null <<< "$status"; then
        echo ${lib.escapeShellArg "Refusing to change Tailscale preferences outside the declared tailnet ${tailnetDomain}. Switch profiles and rerun tailscale-app-preferences."} >&2
        exit 1
      fi
      ${lib.escapeShellArg cli} set ${lib.escapeShellArgs arguments}
      echo "Applied declared Tailscale.app preferences; exit-node selection and authentication are unchanged."
    '';
  };
in
{
  options.services.tailscale-app = {
    enable = lib.mkEnableOption "declarative preferences for the existing Standalone Tailscale.app";
    acceptDNS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept the tailnet DNS configuration.";
    };
    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept subnet routes advertised by other tailnet nodes.";
    };
    shieldsUp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Block incoming tailnet connections, including private Serve endpoints.";
    };
    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow automatic app updates rather than managing upgrades separately.";
    };
    checkForUpdates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Notify about available app updates.";
    };
    startOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set the documented TailscaleStartOnLogin app preference.";
    };
  };

  config = lib.mkMerge [
    {
      # The upstream user-agent cleanup can be skipped when the final agent is
      # removed. Do not leave an old login job applying disabled preferences.
      system.activationScripts.postActivation.text = lib.mkIf (!cfg.enable && user != null) ''
        tailscaleUid=$(id -u -- ${lib.escapeShellArg user})
        if /bin/launchctl print "gui/$tailscaleUid/org.nixos.tailscale-app-preferences" >/dev/null 2>&1; then
          /bin/launchctl bootout "gui/$tailscaleUid/org.nixos.tailscale-app-preferences"
        fi
        rm -f ${lib.escapeShellArg "${home}/Library/LaunchAgents/org.nixos.tailscale-app-preferences.plist"}
        unset tailscaleUid
      '';
    }
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !config.services.tailscale.enable;
          message = "services.tailscale-app cannot run alongside the native services.tailscale daemon.";
        }
        {
          assertion =
            hostname != ""
            && lib.hasPrefix "${lib.toLower hostname}." tailnetHost
            && lib.hasSuffix ".ts.net" tailnetHost;
          message = "services.tailscale-app requires matching hostFacts.hostName and hostFacts.tailnetHost.";
        }
      ];

      environment.systemPackages = [ apply ];
      system.defaults.CustomUserPreferences = lib.optionalAttrs cfg.enable {
        ${lib.escapeShellArg "${home}/Library/Preferences/io.tailscale.ipn.macsys.plist"} = {
          TailscaleStartOnLogin = cfg.startOnLogin;
          SUAutomaticallyUpdate = cfg.autoUpdate;
          SUEnableAutomaticChecks = cfg.checkForUpdates;
        };
      };
      launchd.user.agents.tailscale-app-preferences = {
        command = lib.getExe apply;
        serviceConfig = {
          RunAtLoad = true;
          ProcessType = "Background";
          StandardOutPath = "${home}/.tailscale-app-preferences.log";
          StandardErrorPath = "${home}/.tailscale-app-preferences.log";
        };
      };
      system.activationScripts.postActivation.text = lib.mkAfter ''
        tailscaleUser=${lib.escapeShellArg user}
        tailscaleUid=$(id -u -- "$tailscaleUser")
        if /bin/launchctl print "gui/$tailscaleUid" >/dev/null 2>&1; then
          echo "applying Tailscale.app preferences for $tailscaleUser..." >&2
          /bin/launchctl asuser "$tailscaleUid" /usr/bin/sudo -H -u "$tailscaleUser" -- ${lib.getExe apply}
        else
          echo "Tailscale.app preferences deferred until $tailscaleUser logs in." >&2
        fi
        unset tailscaleUser tailscaleUid
      '';
    })
  ];
}
