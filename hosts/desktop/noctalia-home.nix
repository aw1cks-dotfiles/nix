{ pkgs, ... }:
let
  mumblePttHelper = pkgs.writeShellScriptBin "mumble-ptt-helper" ''
    set -euo pipefail
    exec ${pkgs.python3}/bin/python3 "${./mumble-ptt-helper.py}"
  '';
in
{
  home.packages = [ mumblePttHelper ];

  systemd.user.services.mumble-ptt-helper = {
    Unit = {
      Description = "Hardcoded Mumble push-to-talk helper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStart = "${mumblePttHelper}/bin/mumble-ptt-helper";
      Restart = "always";
      RestartSec = 1;
      TimeoutStopSec = 2;
      KillSignal = "SIGINT";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    plugins = {
      sources = [
        {
          enabled = true;
          name = "Official Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        "network-manager-vpn" = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
      };
      version = 1;
    };
    settings = {
      settingsVersion = 0;

      bar = {
        backgroundOpacity = 0.7;
        contentPadding = 2;
        density = "default";
        fontScale = 1.5;
        displayMode = "always_visible";
        marginHorizontal = 4;
        marginVertical = 4;
        position = "top";
        showCapsule = false;
        widgetSpacing = 8;
        widgets = {
          left = [
            { id = "Launcher"; }
            {
              id = "Workspace";
              hideUnoccupied = false;
              labelMode = "none";
            }
          ];
          center = [
            {
              id = "MediaMini";
              maximumWidth = 500;
            }
          ];
          right = [
            { id = "SystemMonitor"; }
            { id = "NotificationHistory"; }
            {
              id = "Clock";
              formatHorizontal = "HH:mm";
              formatVertical = "HH mm";
              useMonospacedFont = true;
            }
            { id = "VPN"; }
            { id = "ControlCenter"; }
          ];
        };
      };

      appLauncher.terminalCommand = "env SHLVL=0 wezterm";

      controlCenter = {
        cards = [
          {
            enabled = true;
            id = "shortcuts-card";
          }
          {
            enabled = true;
            id = "audio-card";
          }
          {
            enabled = true;
            id = "media-sysmon-card";
          }
        ];
        position = "close_to_bar_button";
        shortcuts = {
          left = [
            { id = "Network"; }
            { id = "Bluetooth"; }
          ];
          right = [
            { id = "Notifications"; }
            { id = "PowerProfile"; }
          ];
        };
      };

      colorSchemes.predefinedScheme = "Oxocarbon";

      dock.enabled = false;

      wallpaper = {
        directory = "/home/alex/Pictures/Wallpapers";
        setWallpaperOnAllMonitors = true;
        linkLightAndDarkWallpapers = true;
      };

      notifications = {
        enabled = true;
        backgroundOpacity = 0.7;
        clearDismissed = true;
        criticalUrgencyDuration = 8;
        location = "top_right";
        lowUrgencyDuration = 8;
        normalUrgencyDuration = 8;
        saveToHistory = {
          critical = true;
          low = true;
          normal = true;
        };
        sounds.enabled = false;
      };

      ui = {
        panelsAttachedToBar = true;
        settingsPanelMode = "attached";
      };
    };
  };

  programs.niri.settings = {
    layout = {
      focus-ring = {
        width = 2;
      };

      preset-column-widths = [
        {
          proportion = 0.5;
        }
        {
          proportion = 1.0;
        }
      ];

      default-column-width = {
        proportion = 1.0;
      };
    };

    input = {
      focus-follows-mouse = {
        enable = true;
        max-scroll-amount = "0%";
      };
    };

    outputs = {
      "ASUSTek COMPUTER INC VG27A K9LMQS060339" = {
        mode = {
          width = 2560;
          height = 1440;
          refresh = 164.999;
        };
        focus-at-startup = true;
        position = {
          x = 2560;
          y = 0;
        };
      };
      "ViewSonic Corporation VA2719-2K UZJ192522589" = {
        mode = {
          width = 2560;
          height = 1440;
          refresh = 59.951;
        };
        position = {
          x = 0;
          y = 0;
        };
      };
    };
    binds = {
      "Mod+Shift+Slash".action.show-hotkey-overlay = { };

      "Mod+Escape" = {
        allow-inhibiting = false;
        action.spawn = [
          "sh"
          "-lc"
          "niri msg action toggle-keyboard-shortcuts-inhibit && ${pkgs.libnotify}/bin/notify-send 'Niri shortcuts' 'Keyboard shortcut inhibiting toggled'"
        ];
      };

      "Mod+D".action.spawn = [
        "noctalia-shell"
        "ipc"
        "call"
        "launcher"
        "toggle"
      ];
      "Mod+Return".action.spawn = [
        "env"
        "SHLVL=0"
        "wezterm"
      ];
      "Mod+Shift+Return".action.spawn = [
        "env"
        "SHLVL=0"
        "wezterm"
      ];
      "Mod+F12".action.spawn = [ "zen-twilight" ];
      "Mod+F11".action.spawn = [ "ytmdesktop" ];
      "Mod+M".action.spawn = [ "mumble" ];
      "Mod+Print".action.screenshot = { };

      "Mod+W".action.toggle-column-tabbed-display = { };

      "Mod+H".action.focus-column-left = { };
      "Mod+L".action.focus-column-right = { };
      "Mod+J".action.focus-window-down = { };
      "Mod+K".action.focus-window-up = { };

      "Mod+Ctrl+H".action.move-column-left = { };
      "Mod+Ctrl+L".action.move-column-right = { };
      "Mod+Ctrl+J".action.move-window-down = { };
      "Mod+Ctrl+K".action.move-window-up = { };

      "Mod+BracketLeft".action.consume-or-expel-window-left = { };
      "Mod+BracketRight".action.consume-or-expel-window-right = { };

      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";

      "Mod+F".action.switch-preset-column-width = { };
      "Mod+Shift+F".action.fullscreen-window = { };

      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;
      "Mod+0".action.focus-workspace = 10;

      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;
      "Mod+Shift+6".action.move-column-to-workspace = 6;
      "Mod+Shift+7".action.move-column-to-workspace = 7;
      "Mod+Shift+8".action.move-column-to-workspace = 8;
      "Mod+Shift+9".action.move-column-to-workspace = 9;
      "Mod+Shift+0".action.move-column-to-workspace = 10;

      "Mod+V".action.toggle-window-floating = { };
      "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = { };

      "Mod+Shift+Q" = {
        repeat = false;
        action.close-window = { };
      };
      "Mod+Shift+E".action.quit = { };

      "Mod+Shift+KP_Enter".action.spawn = [
        "mumble"
        "rpc"
        "toggledeaf"
      ];
      "Mod+KP_Multiply".action.spawn = [
        "wpctl"
        "set-mute"
        "@DEFAULT_AUDIO_SINK@"
        "toggle"
      ];
      "Mod+KP_Home".action.spawn = [
        "playerctl"
        "--all-players"
        "-i"
        "chromium,chrome,firefox"
        "play-pause"
      ];
      "Mod+KP_Up".action.spawn = [
        "playerctl"
        "--all-players"
        "-i"
        "chromium,chrome,firefox"
        "previous"
      ];
      "Mod+KP_Prior".action.spawn = [
        "playerctl"
        "--all-players"
        "-i"
        "chromium,chrome,firefox"
        "next"
      ];
    };

    window-rules = [
      {
        geometry-corner-radius = {
          top-left = 8.0;
          top-right = 8.0;
          bottom-right = 8.0;
          bottom-left = 8.0;
        };
        clip-to-geometry = true;
      }
    ];

    debug = {
      # Allows notification actions and window activation from Noctalia.
      honor-xdg-activation-with-invalid-serial = { };
    };
  };
}
