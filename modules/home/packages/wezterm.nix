# Wezterm - extracted from gui-apps
{ inputs, ... }:
{
  aw1cks.modules.home.wezterm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.wezterm;
      weztermPlatform =
        if pkgs.stdenv.isDarwin then
          "darwin"
        else if pkgs.stdenv.isLinux then
          "linux"
        else
          "unknown";

      luaBool = value: if value then "true" else "false";
      luaNull = value: if value == null then "nil" else toString value;
      luaNullableBool = value: if value == null then "nil" else luaBool value;
      weztermSettings = ''
        return {
          platform = "${weztermPlatform}",
          color_scheme = "${cfg.colorScheme}",
          default_cursor_style = "${cfg.defaultCursorStyle}",
          cursor_blink_rate = ${toString cfg.cursorBlinkRate},
          inactive_pane_hsb = {
            saturation = ${toString cfg.inactivePaneHsb.saturation},
            brightness = ${toString cfg.inactivePaneHsb.brightness},
          },
          font = {
            family = "${cfg.font.family}",
            weight = "${cfg.font.weight}",
            size = ${toString cfg.font.size},
            emoji_fallback = "${cfg.font.emojiFallback}",
          },
          window = {
            background_opacity = ${toString cfg.window.backgroundOpacity},
            decorations = "${cfg.window.decorations}",
            initial_cols = ${toString cfg.window.initialCols},
            initial_rows = ${toString cfg.window.initialRows},
            padding = "${cfg.window.padding}",
            macos_background_blur = ${luaNull cfg.window.macosBackgroundBlur},
            native_macos_fullscreen_mode = ${luaNullableBool cfg.window.nativeMacosFullscreenMode},
            macos_fullscreen_extend_behind_notch = ${luaNullableBool cfg.window.macosFullscreenExtendBehindNotch},
          },
        }
      '';
    in
    {
      options.modules.wezterm = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Wezterm with repo defaults.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.wezterm.packages.${pkgs.stdenv.hostPlatform.system}.default;
          description = "Wezterm package to install.";
        };

        colorSchemes = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {
            "Oxocarbon Dark" = {
              background = "#161616";
              foreground = "#ffffff";
              cursor_bg = "#52ad70";
              cursor_border = "#52ad70";
              cursor_fg = "#52ad70";
              ansi = [
                "#262626"
                "#ee5396"
                "#42be65"
                "#ffe97b"
                "#33b1ff"
                "#ff7eb6"
                "#3ddbd9"
                "#dde1e6"
              ];
              brights = [
                "#393939"
                "#ee5396"
                "#42be65"
                "#ffe97b"
                "#33b1ff"
                "#ff7eb6"
                "#3ddbd9"
                "#ffffff"
              ];
              tab_bar = {
                background = "#262626";
                active_tab = {
                  bg_color = "#161616";
                  fg_color = "#ffffff";
                  intensity = "Normal";
                  italic = false;
                  strikethrough = false;
                  underline = "None";
                };
                inactive_tab = {
                  bg_color = "#262626";
                  fg_color = "#ffffff";
                  intensity = "Normal";
                  italic = false;
                  strikethrough = false;
                  underline = "None";
                };
                new_tab = {
                  bg_color = "#262626";
                  fg_color = "#ffffff";
                  intensity = "Normal";
                  italic = false;
                  strikethrough = false;
                  underline = "None";
                };
              };
            };
          };
          description = "Configured wezterm color schemes.";
        };

        colorScheme = lib.mkOption {
          type = lib.types.str;
          default = "Oxocarbon Dark";
          description = "Default color scheme name.";
        };

        defaultCursorStyle = lib.mkOption {
          type = lib.types.str;
          default = "BlinkingUnderline";
          description = "Default cursor style.";
        };

        cursorBlinkRate = lib.mkOption {
          type = lib.types.int;
          default = 400;
          description = "Cursor blink rate in milliseconds.";
        };

        inactivePaneHsb = lib.mkOption {
          type = lib.types.submodule {
            options = {
              saturation = lib.mkOption {
                type = lib.types.number;
                default = 0.4;
              };
              brightness = lib.mkOption {
                type = lib.types.number;
                default = 0.5;
              };
            };
          };
          default = { };
          description = "Inactive pane color adjustments.";
        };

        font = lib.mkOption {
          type = lib.types.submodule {
            options = {
              family = lib.mkOption {
                type = lib.types.str;
                default = "CaskaydiaMono Nerd Font";
              };
              weight = lib.mkOption {
                type = lib.types.str;
                default = "Medium";
              };
              size = lib.mkOption {
                type = lib.types.int;
                default = if pkgs.stdenv.isDarwin || pkgs.stdenv.isLinux then 18 else 14;
              };
              emojiFallback = lib.mkOption {
                type = lib.types.str;
                default = if pkgs.stdenv.isDarwin || pkgs.stdenv.isLinux then "Apple Color Emoji" else "JoyPixels";
              };
            };
          };
          default = { };
          description = "Default font configuration.";
        };

        window = lib.mkOption {
          type = lib.types.submodule {
            options = {
              backgroundOpacity = lib.mkOption {
                type = lib.types.number;
                default = if pkgs.stdenv.isDarwin then 0.75 else 0.85;
              };
              decorations = lib.mkOption {
                type = lib.types.str;
                default = if pkgs.stdenv.isLinux then "NONE" else "TITLE | RESIZE";
              };
              initialCols = lib.mkOption {
                type = lib.types.int;
                default =
                  if pkgs.stdenv.isDarwin then
                    120
                  else if pkgs.stdenv.isLinux then
                    180
                  else
                    80;
              };
              initialRows = lib.mkOption {
                type = lib.types.int;
                default =
                  if pkgs.stdenv.isDarwin then
                    36
                  else if pkgs.stdenv.isLinux then
                    48
                  else
                    24;
              };
              padding = lib.mkOption {
                type = lib.types.str;
                default = "2%";
              };
              macosBackgroundBlur = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = if pkgs.stdenv.isDarwin then 20 else null;
              };
              nativeMacosFullscreenMode = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = if pkgs.stdenv.isDarwin then false else null;
              };
              macosFullscreenExtendBehindNotch = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = if pkgs.stdenv.isDarwin then true else null;
              };
            };
          };
          default = { };
          description = "Window layout defaults.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.wezterm = {
          enable = true;
          package = cfg.package;
          inherit (cfg) colorSchemes;
        };

        xdg.configFile = {
          "wezterm/appearance.lua".source = ./files/wezterm/appearance.lua;
          "wezterm/binds.lua".source = ./files/wezterm/binds.lua;
          "wezterm/wezterm.lua".source = ./files/wezterm/wezterm.lua;
          "wezterm/settings.lua".text = weztermSettings;
        };
      };
    };
}
