{ ... }:
let
  noctaliaSettings = {
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
in
{
  programs.noctalia-shell = {
    enable = true;
    settings = noctaliaSettings;
  };

  xdg.configFile."autostart/noctalia-shell.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Noctalia Shell
    Exec=noctalia-shell
    Terminal=false
    OnlyShowIn=niri;
    X-GNOME-Autostart-enabled=true
  '';

  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
}
