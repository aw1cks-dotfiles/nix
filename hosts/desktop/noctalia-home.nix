{ ... }:
let
  noctaliaSettings = {
    settingsVersion = 0;

    bar = {
      density = "compact";
      position = "top";
      widgets = {
        left = [
          { id = "Launcher"; }
        ];
        center = [
          {
            id = "Workspace";
            hideUnoccupied = false;
            labelMode = "none";
          }
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
