{ ... }:
{
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    settings = {
      settingsVersion = 0;

      bar = {
        backgroundOpacity = 0.7;
        contentPadding = 2;
        density = "compact";
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
            { id = "MediaMini"; }
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
            { id = "ControlCenter"; }
          ];
        };
      };

      appLauncher.terminalCommand = "wezterm start --";

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

      dock.enabled = false;

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

      "Mod+D".action.spawn = [
        "noctalia-shell"
        "ipc"
        "call"
        "launcher"
        "toggle"
      ];
      "Mod+Return".action.spawn = [ "wezterm" ];
      "Mod+Shift+Return".action.spawn = [ "wezterm" ];
      "Mod+F12".action.spawn = [ "zen-twilight" ];
      "Mod+F11".action.spawn = [ "ytmdesktop" ];
      "Mod+BracketRight".action.spawn = [ "mumble" ];
      "Mod+Print".action.screenshot = { };

      "Mod+Left".action.focus-workspace-up = { };
      "Mod+Right".action.focus-workspace-down = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Down".action.focus-window-down = { };

      "Mod+Shift+Up".action.move-window-up = { };
      "Mod+Shift+Down".action.move-window-down = { };

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

      "Mod+F".action.fullscreen-window = { };
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
          top-left = 20.0;
          top-right = 20.0;
          bottom-right = 20.0;
          bottom-left = 20.0;
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
