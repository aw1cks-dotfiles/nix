{ config, ... }:
let
  sharedFonts = config.aw1cks.fonts;
in
{
  aw1cks.modules.home.tern =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.tern;
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      supportedSystems = builtins.attrNames (import ../../integrations/_tern-sources.nix).artifacts;
      desktop = import ../../integrations/_tern-desktop.nix;
      json = pkgs.formats.json { };
      bindings = import ./_tern/keybindings.nix {
        inherit lib isDarwin;
        primary = cfg.keyboard.primaryModifier;
        prefix = cfg.keyboard.prefix;
      };
      defaults = {
        font_family = lib.concatStringsSep ", " cfg.fonts.terminal;
        code_font = lib.concatStringsSep ", " cfg.fonts.terminal;
        ui_font = lib.concatStringsSep ", " cfg.fonts.interface;
        font_size = cfg.fonts.size;
        ui_font_size = cfg.fonts.interfaceSize;
        font_weight = cfg.fonts.weight;
        padding_x = cfg.padding.horizontal;
        padding_y = cfg.padding.vertical;
        link_target = "Tern";
        agent_placement = "new_tab";
        cursor = {
          shape = "underline";
          blink = true;
          programs = true;
          editors = false;
        };
      }
      // lib.optionalAttrs (cfg.package != null) { auto_update = false; }
      // lib.optionalAttrs isDarwin { option_as_alt = cfg.keyboard.optionAsAlt; }
      // lib.optionalAttrs cfg.keyboard.enable { keybinds = bindings; };
      managed = json.generate "tern-managed-settings.json" (lib.recursiveUpdate defaults cfg.settings);
      environment = cfg.environment // {
        TERN_CONFIG_DIR = cfg.configDirectory;
        TERN_DAEMON_SOCKET = cfg.socket;
      };
      launcher = pkgs.writeShellScriptBin "tern" ''
        ${lib.toShellVars environment}
        export ${lib.concatStringsSep " " (builtins.attrNames environment)}
        export PATH=${
          lib.escapeShellArg (lib.makeBinPath [ config.home.profileDirectory ])
        }''${PATH:+:}''${PATH:-}
        exec ${lib.escapeShellArg cfg.executable} "$@"
      '';
      macLauncher = pkgs.runCommand "tern-managed-app" { } ''
        mkdir -p "$out/Tern Managed.app/Contents/MacOS"
        cp ${pkgs.writeText "tern-managed-info.plist" ''
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0"><dict>
          <key>CFBundleIdentifier</key><string>org.nixos.tern-managed</string>
          <key>CFBundleName</key><string>Tern Managed</string>
          <key>CFBundleExecutable</key><string>tern</string>
          <key>CFBundlePackageType</key><string>APPL</string>
          </dict></plist>
        ''} "$out/Tern Managed.app/Contents/Info.plist"
        cp ${launcher}/bin/tern "$out/Tern Managed.app/Contents/MacOS/tern"
      '';
    in
    {
      imports = [
        ./_tern/services.nix
        ./_tern/themes.nix
      ];

      options.modules.tern = {
        enable = lib.mkEnableOption "declarative Tern settings and a managed launcher";
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default =
            if builtins.elem pkgs.stdenv.hostPlatform.system supportedSystems then
              import ../../integrations/_tern-package.nix { inherit pkgs; }
            else
              null;
          description = "Pinned Tern binary package, requiring a manually imported authenticated archive. Null selects an externally installed executable.";
        };
        executable = lib.mkOption {
          type = lib.types.str;
          default =
            if cfg.package != null then
              lib.getExe cfg.package
            else if isDarwin then
              "/Applications/Tern.app/Contents/MacOS/tern"
            else
              "";
          description = "Absolute path to the real backend executable, not the managed tern launcher or profile command. Defaults to the selected package; required on Linux when package is null.";
        };
        configDirectory = lib.mkOption {
          type = lib.types.str;
          default =
            if isDarwin then
              "${config.home.homeDirectory}/Library/Application Support/Tern"
            else
              "${config.xdg.configHome}/tern";
          description = "Tern configuration directory inside the home. TERN_CONFIG_DIR also places Tern's application state here.";
        };
        stateDirectory = lib.mkOption {
          type = lib.types.str;
          default = cfg.configDirectory;
          description = "Default remote identity/state directory and location of the local daemon socket.";
        };
        socket = lib.mkOption {
          type = lib.types.strMatching "/.*";
          default = "${cfg.stateDirectory}/daemon.sock";
          description = "Session socket shared by managed GUI, CLI and user services.";
        };
        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Additional launcher/service environment. Managed configuration and socket variables take precedence.";
        };
        settings = lib.mkOption {
          type = lib.types.attrsOf json.type;
          default = { };
          description = "Tern settings merged over module defaults. Only declared leaves are owned; unrelated settings and keybinds remain writable. Do not put secrets here.";
        };
        keyboard = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Install cohesive physical-key bindings and the prefix map.";
          };
          primaryModifier = lib.mkOption {
            type = lib.types.str;
            default = if isDarwin then "cmd" else "ctrl+shift";
            description = "Modifiers for splits, focus, new tabs and numbered tabs.";
          };
          prefix = lib.mkOption {
            type = lib.types.str;
            default = "shift+space";
            description = "Sequence prefix; Shift+Space is reserved rather than inserted. Following keys are unmodified.";
          };
          optionAsAlt = lib.mkOption {
            type = lib.types.enum [
              "auto"
              "off"
              "both"
              "left"
              "right"
            ];
            default = "left";
            description = "macOS only: Left Option sends native Meta/Alt while Right Option retains layout characters.";
          };
        };
        fonts = {
          terminal = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = sharedFonts.defaults.monospace;
            description = "Terminal/code font family fallback list, shared with the desktop font policy.";
          };
          interface = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = sharedFonts.defaults.sansSerif;
            description = "Interface font family fallback list, shared with the desktop font policy.";
          };
          size = lib.mkOption {
            type = lib.types.ints.between 8 32;
            default = lib.min 32 (lib.attrByPath [ "modules" "wezterm" "font" "size" ] 18 config);
            description = "Terminal font size in Tern pixels; uses WezTerm's nominal size without applying an extra DPI conversion.";
          };
          interfaceSize = lib.mkOption {
            type = lib.types.nullOr (lib.types.ints.between 8 32);
            default = lib.max 8 (cfg.fonts.size - 2);
            description = "UI font size in pixels; defaults to two pixels below the terminal size, with an 8px minimum. Null follows the terminal size.";
          };
          weight = lib.mkOption {
            type = lib.types.ints.between 100 900;
            default = 500;
            description = "Terminal font weight; 500 is Medium, matching WezTerm.";
          };
        };
        padding = {
          horizontal = lib.mkOption {
            type = lib.types.ints.between 0 40;
            default = 16;
            description = "Horizontal terminal-content padding in pixels.";
          };
          vertical = lib.mkOption {
            type = lib.types.ints.between 0 40;
            default = 12;
            description = "Vertical terminal-content padding in pixels.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = isDarwin || pkgs.stdenv.hostPlatform.isLinux;
            message = "Tern requires Darwin or Linux.";
          }
          {
            assertion = lib.hasPrefix "/" cfg.executable;
            message = "modules.tern requires an absolute executable when package is null.";
          }
          {
            assertion = builtins.stringLength cfg.socket < (if isDarwin then 104 else 108);
            message = "modules.tern.socket exceeds the platform's Unix-domain socket path limit; choose a shorter socket path.";
          }
          {
            assertion = lib.hasPrefix "${config.home.homeDirectory}/" cfg.configDirectory;
            message = "modules.tern.configDirectory must be inside home.homeDirectory for managed theme files.";
          }
          {
            assertion = lib.all (name: builtins.match "[A-Za-z_][A-Za-z0-9_]*" name != null) (
              builtins.attrNames cfg.environment
            );
            message = "modules.tern.environment keys must be shell environment variable names.";
          }
        ];
        # Shadow the package's raw CLI without recursively resolving it on PATH.
        home.packages = [ (lib.hiPrio launcher) ] ++ lib.optional (cfg.package != null) cfg.package;
        # New services must read the merged preferences, not the previous
        # generation's settings. Keep startup after both file linking and merge.
        home.activation.ternSettings =
          lib.hm.dag.entryBetween [ "setupLaunchAgents" "reloadSystemd" ] [ "writeBoundary" "linkGeneration" ]
            ''
              run ${pkgs.coreutils}/bin/install -d -m 700 -- ${lib.escapeShellArg cfg.configDirectory}
              run ${pkgs.python3}/bin/python3 ${./_tern/merge-settings.py} \
                --settings ${lib.escapeShellArg "${cfg.configDirectory}/settings.json"} \
                --managed ${managed} \
                --state ${lib.escapeShellArg "${cfg.configDirectory}/.nix-settings-state.json"}
            '';
        home.file = lib.mkIf isDarwin {
          "Applications/Tern Managed.app".source = "${macLauncher}/Tern Managed.app";
        };
        xdg.desktopEntries = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          "${desktop.applicationId}" = {
            name = "Tern Managed";
            genericName = "Terminal";
            exec = "${launcher}/bin/tern %F";
            icon = desktop.applicationId;
            terminal = false;
            categories = [
              "System"
              "TerminalEmulator"
            ];
            settings = {
              StartupWMClass = desktop.applicationId;
              X-TerminalArgExec = "-e";
            };
          };
          "${desktop.applicationId}.url" = {
            name = "Tern Managed";
            exec = "${launcher}/bin/tern --open-url %u";
            icon = desktop.applicationId;
            noDisplay = true;
            mimeType = [ "x-scheme-handler/tern" ];
            settings.StartupWMClass = desktop.applicationId;
          };
          "${desktop.applicationId}.open" = {
            name = "Tern Managed";
            exec = "${launcher}/bin/tern --open-file %f";
            icon = desktop.applicationId;
            noDisplay = true;
            mimeType = desktop.mimeTypes;
            settings.StartupWMClass = desktop.applicationId;
          };
        };
      };
    };
}
