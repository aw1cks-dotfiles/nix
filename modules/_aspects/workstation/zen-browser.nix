# Zen Browser — migrated from dendritic-lib/modules/editor/zen-browser.nix
# Note: This module requires the zen-browser flake input.
# The zen-browser home module is imported via inputs in the deferred module.
{ dl, inputs, ... }:
{
  dl.workstation-zen-browser.homeManager =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.modules.zen-browser;
      browserDesktopFile = "zen-twilight.desktop";
      myMimeApps = pkgs.writeText "mimeapps.list" ''
        [Default Applications]
        text/html=${browserDesktopFile}
        application/xhtml+xml=${browserDesktopFile}
        x-scheme-handler/http=${browserDesktopFile}
        x-scheme-handler/https=${browserDesktopFile}
        x-scheme-handler/about=${browserDesktopFile}
        x-scheme-handler/unknown=${browserDesktopFile}

        [Added Associations]
        text/html=${browserDesktopFile};
        application/xhtml+xml=${browserDesktopFile};
        x-scheme-handler/http=${browserDesktopFile};
        x-scheme-handler/https=${browserDesktopFile};
      '';
    in
    {
      # TEMPORARILY REMOVED FOR DEBUGGING
      # imports = [ inputs.zen-browser.homeModules.twilight-official ];

      options.modules.zen-browser = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Zen Browser.";
        };
        defaultAsSystemBrowser = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Set Zen Browser as the default system browser.";
        };
        plugins = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            "uBlock0@raymondhill.net" = "ublock-origin";
            "{446900e4-71c2-419f-a6a7-df9c091e268b}" = "bitwarden-password-manager";
            "addon@darkreader.org" = "darkreader";
          };
          description = "A set of browser extensions to install in Zen Browser.";
        };
        policies = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Browser policies to merge with defaults.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.activation = lib.optionalAttrs cfg.defaultAsSystemBrowser {
          applyZenBrowserDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ -L "$HOME/.config/mimeapps.list" ]; then
              $DRY_RUN_CMD rm -f "$HOME/.config/mimeapps.list"
            fi
            if [ ! -f "$HOME/.config/mimeapps.list" ]; then
              $DRY_RUN_CMD cp "${myMimeApps}" "$HOME/.config/mimeapps.list"
              $DRY_RUN_CMD chmod +w "$HOME/.config/mimeapps.list"
            fi
          '';
        };

        programs.zen-browser = {
          enable = true;
          profiles.default = {
            id = 0;
            isDefault = true;
          };
          policies =
            let
              mkExtensionSettings = builtins.mapAttrs (
                _: pluginId: {
                  install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
                  installation_mode = "force_installed";
                }
              );
              defaultPolicies = {
                ExtensionSettings = mkExtensionSettings cfg.plugins;
                AutofillAddressEnabled = false;
                AutofillCreditCardEnabled = false;
                DisableAppUpdate = true;
                DisableFeedbackCommands = true;
                DisableFirefoxStudies = true;
                DisablePocket = true;
                DisableTelemetry = true;
                DontCheckDefaultBrowser = true;
                NoDefaultBookmarks = true;
                OfferToSaveLogins = true;
                EnableTrackingProtection = {
                  Value = true;
                  Locked = true;
                  Cryptomining = true;
                  Fingerprinting = true;
                };
                GenerativeAI = {
                  Enabled = false;
                  Chatbot = false;
                  LinkPreviews = false;
                  TabGroups = false;
                  Locked = false;
                };
              };
            in
            lib.recursiveUpdate defaultPolicies cfg.policies;
        };
      };
    };
}
