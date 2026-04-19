{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  mumblePttHelper = pkgs.writeShellScriptBin "mumble-ptt-helper" ''
    set -euo pipefail
    exec ${pkgs.python3}/bin/python3 "${./mumble-ptt-helper.py}"
  '';

  kdl = inputs.niri.lib.kdl;

  niriSettings = {
    spawn-at-startup = [
      {
        command = [
          "noctalia-shell"
        ];
      }
      {
        argv = [
          "${pkgs.dbus}/bin/dbus-update-activation-environment"
          "--systemd"
          "DISPLAY"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_TYPE"
          "NIRI_SOCKET"
        ];
      }
      {
        argv = [
          "${pkgs.systemd}/bin/systemctl"
          "--user"
          "import-environment"
          "DISPLAY"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
          "XDG_SESSION_TYPE"
          "NIRI_SOCKET"
        ];
      }
      {
        argv = [
          "${pkgs.systemd}/bin/systemctl"
          "--user"
          "restart"
          "xdg-desktop-portal-gtk.service"
          "xdg-desktop-portal-gnome.service"
          "xdg-desktop-portal.service"
        ];
      }
    ];

    prefer-no-csd = true;

    cursor = {
      size = 24;
      theme = "macOS-White";
    };

    hotkey-overlay = {
      skip-at-startup = true;
    };

    environment = {
      QT_QPA_PLATFORMTHEME = "gtk3";
      SHLVL = "0";
    };

    layout = {
      focus-ring = {
        enable = true;
        width = 2;
        active.color = "#33b1ff";
        inactive.color = "#525252";
        urgent.color = "#be95ff";
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
      "Mod+Return".action.spawn = [ "wezterm" ];
      "Mod+Shift+Return".action.spawn = [ "wezterm" ];
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
      honor-xdg-activation-with-invalid-serial = { };
    };
  };

  niriRenderedConfig =
    (lib.evalModules {
      modules = [
        inputs.niri.lib.internal.settings-module
        { config.programs.niri.settings = niriSettings; }
      ];
    }).config.programs.niri.config;
in
{
  home.packages = with pkgs; [
    apple-cursor
    adwaita-icon-theme
    adw-gtk3
    libsForQt5.qt5ct
    morewaita-icon-theme
    mumblePttHelper
    qt6Packages.qt6ct
  ];

  home.pointerCursor = {
    name = "macOS-White";
    package = pkgs.apple-cursor;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  stylix.targets.gtk.enable = false;

  gtk = {
    enable = true;
    iconTheme = {
      name = "MoreWaita";
      package = pkgs.morewaita-icon-theme;
    };
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-size = 24;
    cursor-theme = "macOS-White";
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "MoreWaita";
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = "";
  };

  xdg.configFile."noctalia/colorschemes/Oxocarbon-secondary-tertiary-swap/Oxocarbon-secondary-tertiary-swap.json".text =
    ''
      {
        "dark": {
          "mPrimary": "#33b1ff",
          "mOnPrimary": "#161616",
          "mSecondary": "#be95ff",
          "mOnSecondary": "#161616",
          "mTertiary": "#42be65",
          "mOnTertiary": "#161616",
          "mError": "#ee5396",
          "mOnError": "#161616",
          "mSurface": "#161616",
          "mOnSurface": "#f2f4f8",
          "mSurfaceVariant": "#262626",
          "mOnSurfaceVariant": "#dde1e6",
          "mOutline": "#525252",
          "mShadow": "#000000",
          "mHover": "#78a9ff",
          "mOnHover": "#161616",
          "terminal": {
            "normal": {
              "black": "#262626",
              "red": "#ee5396",
              "green": "#42be65",
              "yellow": "#82cfff",
              "blue": "#33b1ff",
              "magenta": "#ff7eb6",
              "cyan": "#3ddbd9",
              "white": "#dde1e6"
            },
            "bright": {
              "black": "#393939",
              "red": "#ee5396",
              "green": "#42be65",
              "yellow": "#82cfff",
              "blue": "#33b1ff",
              "magenta": "#ff7eb6",
              "cyan": "#3ddbd9",
              "white": "#ffffff"
            },
            "foreground": "#f2f4f8",
            "background": "#161616",
            "selectionFg": "#161616",
            "selectionBg": "#f2f4f8",
            "cursorText": "#161616",
            "cursor": "#f2f4f8"
          }
        },
        "light": {
          "mPrimary": "#0f62fe",
          "mOnPrimary": "#f2f4f8",
          "mSecondary": "#673ab7",
          "mOnSecondary": "#f2f4f8",
          "mTertiary": "#42be65",
          "mOnTertiary": "#f2f4f8",
          "mError": "#ee5396",
          "mOnError": "#f2f4f8",
          "mSurface": "#f2f4f8",
          "mOnSurface": "#161616",
          "mSurfaceVariant": "#dde1e6",
          "mOnSurfaceVariant": "#393939",
          "mOutline": "#525252",
          "mShadow": "#ffffff",
          "mHover": "#0f62fe",
          "mOnHover": "#f2f4f8",
          "terminal": {
            "normal": {
              "black": "#525252",
              "red": "#ee5396",
              "green": "#42be65",
              "yellow": "#ffab91",
              "blue": "#0f62fe",
              "magenta": "#be95ff",
              "cyan": "#08bdba",
              "white": "#ffffff"
            },
            "bright": {
              "black": "#161616",
              "red": "#ff7eb6",
              "green": "#42be65",
              "yellow": "#ffab91",
              "blue": "#0f62fe",
              "magenta": "#673ab7",
              "cyan": "#08bdba",
              "white": "#f2f2f2"
            },
            "foreground": "#161616",
            "background": "#f2f4f8",
            "selectionFg": "#f2f4f8",
            "selectionBg": "#0f62fe",
            "cursorText": "#f2f4f8",
            "cursor": "#161616"
          }
        }
      }
    '';

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  xdg.configFile."qt5ct/qt5ct.conf".text = ''
    [Appearance]
    color_scheme_path=$HOME/.config/qt5ct/colors/noctalia.conf
  '';

  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    color_scheme_path=$HOME/.config/qt6ct/colors/noctalia.conf
  '';

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
    # systemd.enable = true;
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

      audio = {
        mprisBlacklist = [ ];
        preferredPlayer = "";
        spectrumFrameRate = 30;
        spectrumMirrored = true;
        visualizerType = "linear";
        volumeFeedback = false;
        volumeFeedbackSoundFile = "";
        volumeOverdrive = false;
        volumeStep = 5;
      };

      brightness = {
        backlightDeviceMappings = [ ];
        brightnessStep = 5;
        enableDdcSupport = false;
        enforceMinimum = true;
      };

      calendar = {
        cards = [
          {
            enabled = true;
            id = "calendar-header-card";
          }
          {
            enabled = true;
            id = "calendar-month-card";
          }
          {
            enabled = true;
            id = "weather-card";
          }
        ];
      };

      desktopWidgets = {
        enabled = false;
        gridSnap = false;
        gridSnapScale = false;
        monitorWidgets = [ ];
        overviewEnabled = true;
      };

      general = {
        allowPanelsOnScreenWithoutBar = true;
        allowPasswordWithFprintd = false;
        animationDisabled = false;
        animationSpeed = 1.25;
        autoStartAuth = false;
        avatarImage = "/home/alex/.face";
        boxRadiusRatio = 1;
        clockFormat = "hh\\nmm";
        clockStyle = "custom";
        compactLockScreen = false;
        dimmerOpacity = 0.1;
        enableBlurBehind = true;
        enableLockScreenCountdown = true;
        enableLockScreenMediaControls = false;
        enableShadows = true;
        forceBlackScreenCorners = false;
        iRadiusRatio = 1;
        keybinds = {
          keyDown = [ "Down" ];
          keyEnter = [
            "Return"
            "Enter"
          ];
          keyEscape = [ "Esc" ];
          keyLeft = [ "Left" ];
          keyRemove = [ "Del" ];
          keyRight = [ "Right" ];
          keyUp = [ "Up" ];
        };
        language = "";
        lockOnSuspend = true;
        lockScreenAnimations = false;
        lockScreenBlur = 0;
        lockScreenCountdownDuration = 10000;
        lockScreenMonitors = [ ];
        lockScreenTint = 0;
        passwordChars = false;
        radiusRatio = 1;
        reverseScroll = false;
        scaleRatio = 1;
        screenRadiusRatio = 1;
        shadowDirection = "bottom_right";
        shadowOffsetX = 2;
        shadowOffsetY = 3;
        showChangelogOnStartup = true;
        showHibernateOnLockScreen = false;
        showScreenCorners = false;
        showSessionButtonsOnLockScreen = true;
        smoothScrollEnabled = true;
        telemetryEnabled = false;
      };

      hooks = {
        colorGeneration = "";
        darkModeChange = "";
        enabled = false;
        performanceModeDisabled = "";
        performanceModeEnabled = "";
        screenLock = "";
        screenUnlock = "";
        session = "";
        startup = "";
        wallpaperChange = "";
      };

      idle = {
        customCommands = "[]";
        enabled = false;
        fadeDuration = 5;
        lockCommand = "";
        lockTimeout = 660;
        resumeLockCommand = "";
        resumeScreenOffCommand = "";
        resumeSuspendCommand = "";
        screenOffCommand = "";
        screenOffTimeout = 600;
        suspendCommand = "";
        suspendTimeout = 1800;
      };

      location = {
        analogClockInCalendar = false;
        autoLocate = false;
        firstDayOfWeek = -1;
        hideWeatherCityName = false;
        hideWeatherTimezone = false;
        name = "London, UK";
        showCalendarEvents = true;
        showCalendarWeather = true;
        showWeekNumberInCalendar = false;
        use12hourFormat = false;
        useFahrenheit = false;
        weatherEnabled = true;
        weatherShowEffects = true;
        weatherTaliaMascotAlways = false;
      };

      network = {
        bluetoothAutoConnect = true;
        bluetoothDetailsViewMode = "grid";
        bluetoothHideUnnamedDevices = false;
        bluetoothRssiPollIntervalMs = 60000;
        bluetoothRssiPollingEnabled = false;
        disableDiscoverability = false;
        networkPanelView = "wifi";
        wifiDetailsViewMode = "grid";
      };

      nightLight = {
        autoSchedule = true;
        dayTemp = "6500";
        enabled = false;
        forced = false;
        manualSunrise = "06:30";
        manualSunset = "18:30";
        nightTemp = "4000";
      };

      noctaliaPerformance = {
        disableDesktopWidgets = true;
        disableWallpaper = true;
      };

      osd = {
        autoHideMs = 2000;
        backgroundOpacity = 0.25;
        enabled = true;
        enabledTypes = [
          0
          1
          2
        ];
        location = "top_right";
        monitors = [ ];
        overlayLayer = true;
      };

      plugins = {
        autoUpdate = false;
        notifyUpdates = true;
      };

      sessionMenu = {
        countdownDuration = 10000;
        enableCountdown = true;
        largeButtonsLayout = "single-row";
        largeButtonsStyle = true;
        position = "center";
        powerOptions = [
          {
            action = "lock";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "1";
          }
          {
            action = "suspend";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "2";
          }
          {
            action = "hibernate";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "3";
          }
          {
            action = "reboot";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "4";
          }
          {
            action = "logout";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "5";
          }
          {
            action = "shutdown";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "6";
          }
          {
            action = "rebootToUefi";
            command = "";
            countdownEnabled = true;
            enabled = true;
            keybind = "7";
          }
          {
            action = "userspaceReboot";
            command = "";
            countdownEnabled = true;
            enabled = false;
            keybind = "";
          }
        ];
        showHeader = true;
        showKeybinds = true;
      };

      systemMonitor = {
        batteryCriticalThreshold = 5;
        batteryWarningThreshold = 20;
        cpuCriticalThreshold = 90;
        cpuWarningThreshold = 80;
        criticalColor = "";
        diskAvailCriticalThreshold = 10;
        diskAvailWarningThreshold = 20;
        diskCriticalThreshold = 90;
        diskWarningThreshold = 80;
        enableDgpuMonitoring = true;
        externalMonitor = "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor";
        gpuCriticalThreshold = 90;
        gpuWarningThreshold = 80;
        memCriticalThreshold = 90;
        memWarningThreshold = 80;
        swapCriticalThreshold = 90;
        swapWarningThreshold = 80;
        tempCriticalThreshold = 90;
        tempWarningThreshold = 80;
        useCustomColors = false;
        warningColor = "";
      };

      templates = {
        activeTemplates = [ ];
        enableUserTheming = false;
      };

      bar = {
        autoHideDelay = 500;
        autoShowDelay = 150;
        backgroundOpacity = 0.25;
        barType = "simple";
        capsuleColorKey = "none";
        capsuleOpacity = 1;
        contentPadding = 2;
        density = "comfortable";
        enableExclusionZoneInset = true;
        fontScale = 1.4;
        displayMode = "always_visible";
        frameRadius = 12;
        frameThickness = 8;
        hideOnOverview = false;
        marginHorizontal = 4;
        marginVertical = 4;
        middleClickAction = "none";
        middleClickCommand = "";
        middleClickFollowMouse = false;
        monitors = [ ];
        mouseWheelAction = "none";
        mouseWheelWrap = true;
        outerCorners = true;
        reverseScroll = false;
        rightClickAction = "controlCenter";
        rightClickCommand = "";
        rightClickFollowMouse = true;
        screenOverrides = [ ];
        position = "top";
        showOnWorkspaceSwitch = true;
        showOutline = false;
        useSeparateOpacity = false;
        showCapsule = false;
        widgetSpacing = 8;
        widgets = {
          left = [
            { id = "Launcher"; }
            {
              id = "Workspace";
              characterCount = 2;
              colorizeIcons = false;
              enableScrollWheel = true;
              focusedColor = "primary";
              followFocusedScreen = false;
              fontWeight = "bold";
              groupedBorderOpacity = 1;
              hideUnoccupied = true;
              iconScale = 0.8;
              pillSize = 0.5;
              showApplications = false;
              showApplicationsHover = false;
              showBadge = false;
              showLabelsOnlyWhenOccupied = true;
              unfocusedIconsOpacity = 1;
              labelMode = "none";
            }
          ];
          center = [
            {
              id = "MediaMini";
              compactMode = false;
              hideMode = "hidden";
              maxWidth = 1000;
              panelShowAlbumArt = true;
              scrollingMode = "hover";
              showAlbumArt = true;
              showArtistFirst = true;
              showProgressRing = true;
              showVisualizer = false;
              textColor = "none";
              useFixedWidth = false;
              visualizerType = "linear";
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

      appLauncher = {
        iconMode = "tabler";
        terminalCommand = "wezterm";
      };

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
        diskPath = "/";
      };

      colorSchemes = {
        darkMode = true;
        generationMethod = "tonal-spot";
        manualSunrise = "06:30";
        manualSunset = "18:30";
        monitorForColors = "";
        schedulingMode = "off";
        syncGsettings = true;
        useWallpaperColors = false;
        predefinedScheme = "Oxocarbon-secondary-tertiary-swap";
      };

      dock = {
        animationSpeed = 1;
        backgroundOpacity = 1;
        colorizeIcons = false;
        deadOpacity = 0.6;
        displayMode = "auto_hide";
        dockType = "floating";
        floatingRatio = 1;
        groupApps = false;
        groupClickAction = "cycle";
        groupContextMenuMode = "extended";
        groupIndicatorStyle = "dots";
        inactiveIndicators = false;
        indicatorColor = "primary";
        indicatorOpacity = 0.6;
        indicatorThickness = 3;
        launcherIcon = "";
        launcherIconColor = "none";
        launcherPosition = "end";
        launcherUseDistroLogo = false;
        monitors = [ ];
        onlySameOutput = true;
        pinnedApps = [ ];
        pinnedStatic = false;
        position = "bottom";
        showDockIndicator = false;
        showLauncherIcon = false;
        sitOnFrame = false;
        size = 1;
      };

      dock.enabled = false;

      notifications = {
        enabled = true;
        density = "default";
        backgroundOpacity = 0.25;
        enableBatteryToast = true;
        enableKeyboardLayoutToast = true;
        enableMarkdown = false;
        enableMediaToast = false;
        clearDismissed = true;
        criticalUrgencyDuration = 8;
        monitors = [ ];
        location = "top_right";
        overlayLayer = true;
        lowUrgencyDuration = 8;
        respectExpireTimeout = false;
        normalUrgencyDuration = 8;
        saveToHistory = {
          critical = true;
          low = true;
          normal = true;
        };
        sounds = {
          criticalSoundFile = "";
          excludedApps = "discord,firefox,chrome,chromium,edge";
          lowSoundFile = "";
          normalSoundFile = "";
          separateSounds = false;
          volume = 0.5;
          enabled = false;
        };
      };

      ui = {
        boxBorderEnabled = false;
        fontDefault = "Sans";
        fontDefaultScale = 1;
        fontFixed = "monospace";
        fontFixedScale = 1;
        panelBackgroundOpacity = 0.45;
        panelsAttachedToBar = true;
        scrollbarAlwaysVisible = true;
        settingsPanelMode = "attached";
        settingsPanelSideBarCardStyle = false;
        tooltipsEnabled = true;
        translucentWidgets = true;
      };

      wallpaper = {
        automationEnabled = true;
        directory = "/home/alex/Pictures/Wallpapers";
        enableMultiMonitorDirectories = true;
        enabled = true;
        favorites = [ ];
        fillColor = "#000000";
        fillMode = "crop";
        hideWallpaperFilenames = false;
        linkLightAndDarkWallpapers = true;
        monitorDirectories = [ ];
        overviewBlur = 0.4;
        overviewEnabled = false;
        overviewTint = 0.6;
        panelPosition = "follow_bar";
        randomIntervalSec = 60;
        setWallpaperOnAllMonitors = true;
        showHiddenFiles = false;
        skipStartupTransition = false;
        solidColor = "#1a1a2e";
        sortOrder = "name";
        transitionDuration = 1500;
        transitionEdgeSmoothness = 0.05;
        transitionType = [ "fade" ];
        useOriginalImages = true;
        useSolidColor = false;
        useWallhaven = false;
        viewMode = "single";
        wallhavenApiKey = "";
        wallhavenCategories = "111";
        wallhavenOrder = "desc";
        wallhavenPurity = "100";
        wallhavenQuery = "";
        wallhavenRatios = "";
        wallhavenResolutionHeight = "";
        wallhavenResolutionMode = "atleast";
        wallhavenResolutionWidth = "";
        wallhavenSorting = "relevance";
        wallpaperChangeMode = "random";
      };
    };
  };

  programs.niri.settings = niriSettings;

  programs.niri.config = niriRenderedConfig ++ [
    (kdl.plain "blur" [
      (kdl.leaf "passes" 3)
      (kdl.leaf "offset" 3.0)
      (kdl.leaf "noise" 0.05)
    ])
    (kdl.plain "layer-rule" [
      (kdl.leaf "match" { namespace = "^noctalia$"; })
      (kdl.leaf "exclude" { namespace = "^(bar|noctalia-background)$"; })
      (kdl.plain "background-effect" [
        (kdl.leaf "blur" true)
        (kdl.leaf "xray" false)
      ])
    ])
    (kdl.plain "layer-rule" [
      (kdl.leaf "match" { namespace = "^(toast|osd|noctalia-popup)$"; })
      (kdl.plain "background-effect" [
        (kdl.leaf "blur" false)
      ])
    ])
    (kdl.plain "window-rule" [
      (kdl.leaf "match" { app-id = "^org.wezfurlong.wezterm$"; })
      (kdl.plain "background-effect" [
        (kdl.leaf "blur" true)
      ])
    ])
  ];
}
