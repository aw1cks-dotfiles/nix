# GUI applications - migrated from nix-old/modules/gui-apps.nix
{ inputs, lib, ... }:
{
  flake.modules.home.gui-apps =
    { pkgs, ... }:
    let
      appleColorEmoji = pkgs.stdenvNoCC.mkDerivation {
        pname = "apple-color-emoji-linux";
        version = "macos-26-20260219-2aa12422";

        src = pkgs.fetchurl {
          url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260219-2aa12422/AppleColorEmoji-Linux.ttf";
          hash = "sha256-U1oEOvBHBtJEcQWeZHRb/IDWYXraLuo0NdxWINwPUxg=";
        };

        dontUnpack = true;

        installPhase = ''
          install -Dm644 "$src" "$out/share/fonts/truetype/AppleColorEmoji-Linux.ttf"
        '';
      };
      weztermPlatform =
        if pkgs.stdenv.isDarwin then
          "darwin"
        else if pkgs.stdenv.isLinux then
          "linux"
        else
          "unknown";
      weztermSettings = ''
        return {
          platform = "${weztermPlatform}",
          color_scheme = "Oxocarbon Dark",
          default_cursor_style = "BlinkingUnderline",
          cursor_blink_rate = 400,
          inactive_pane_hsb = {
            saturation = 0.4,
            brightness = 0.5,
          },
          font = {
            family = "CaskaydiaMono Nerd Font",
            weight = "Medium",
            size = ${if pkgs.stdenv.isDarwin || pkgs.stdenv.isLinux then "18" else "14"},
            emoji_fallback = "${
              if pkgs.stdenv.isDarwin || pkgs.stdenv.isLinux then "Apple Color Emoji" else "JoyPixels"
            }",
          },
          window = {
            background_opacity = ${if pkgs.stdenv.isDarwin then "0.75" else "0.85"},
            decorations = "${if pkgs.stdenv.isLinux then "RESIZE" else "TITLE | RESIZE"}",
            initial_cols = ${
              if pkgs.stdenv.isDarwin then
                "120"
              else if pkgs.stdenv.isLinux then
                "180"
              else
                "80"
            },
            initial_rows = ${
              if pkgs.stdenv.isDarwin then
                "36"
              else if pkgs.stdenv.isLinux then
                "48"
              else
                "24"
            },
            padding = "2%",
            macos_background_blur = ${if pkgs.stdenv.isDarwin then "20" else "nil"},
            native_macos_fullscreen_mode = ${if pkgs.stdenv.isDarwin then "false" else "nil"},
            macos_fullscreen_extend_behind_notch = ${if pkgs.stdenv.isDarwin then "true" else "nil"},
          },
        }
      '';
    in
    {
      home.packages =
        with pkgs;
        [
          cascadia-code
          nerd-fonts.caskaydia-mono
          # Temporarily disabled: current calibre in pinned nixpkgs evaluates as broken on darwin.
          # calibre
          gitkraken
          ibm-plex
          meld
          mumble
          obsidian
          qbittorrent
          slack
          syncplay
          vscode
          wireshark
          zeal
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          appleColorEmoji
          wl-clipboard
          xclip
        ]
        ++ lib.optionals pkgs.stdenv.isDarwin [
          podman-desktop
          utm
          zoom-us
        ];

      fonts.fontconfig.enable = true;

      programs = {
        formiko.enable = pkgs.stdenv.isLinux;
        wezterm = {
          colorSchemes = {
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
          enable = true;
          package = inputs.wezterm.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      };

      xdg.configFile = {
        "wezterm/appearance.lua".source = ./files/wezterm/appearance.lua;
        "wezterm/binds.lua".source = ./files/wezterm/binds.lua;
        "wezterm/wezterm.lua".source = ./files/wezterm/wezterm.lua;
        "wezterm/settings.lua".text = weztermSettings;
      };
    };
}
