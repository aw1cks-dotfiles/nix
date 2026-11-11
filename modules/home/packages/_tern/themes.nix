{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.tern;
  nameType = lib.types.strMatching "[A-Za-z0-9_-]+";
  managedNames = [
    "nix-managed-dark"
    "nix-managed-light"
  ];
  homeRelative = lib.removePrefix "${config.home.homeDirectory}/" cfg.configDirectory;
  selected = lib.filterAttrs (_: name: name != null) {
    dark = cfg.theme.dark;
    light = cfg.theme.light;
  };
  palette = cfg.theme.palette;
  paletteCss = lib.optionalString (palette != null) ''
    :root {
      --tv-bg: ${palette.background};
      --tv-fg: ${palette.foreground};
      --tv-cur: ${palette.cursor_bg};
      --tv-cur-ink: ${palette.background};
    ${lib.concatStringsSep "\n" (
      lib.imap0 (i: color: "  --ansi${toString i}: ${color};") (palette.ansi ++ palette.brights)
    )}
    }
  '';
  sheet =
    appearance: base:
    pkgs.runCommand "tern-${appearance}.css" { } ''
      printf '%s\n' ${lib.escapeShellArg ''
        @import "${base}";
        :root { color-scheme: ${appearance}; }
        ${paletteCss}
      ''} > "$out"
      ${lib.concatMapStringsSep "\n" (file: ''
        cat -- ${lib.escapeShellArg "${file}"} >> "$out"
        printf '\n' >> "$out"
      '') cfg.theme.extraCssFiles}
    '';
  colors = lib.types.addCheck (lib.types.listOf lib.types.str) (values: builtins.length values == 8);
in
{
  options.modules.tern = {
    themes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.source = lib.mkOption {
            type = lib.types.path;
            description = "CSS theme file installed under this registry name, independently of theme selection.";
          };
        }
      );
      default = { };
      description = "Additional CSS themes keyed by safe theme name. Built-in and OMP theme names can also be selected without a registry entry.";
    };
    theme = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Compose and select CSS wrappers for the configured dark/light themes. Does not control installation of theme assets.";
      };
      dark = lib.mkOption {
        type = lib.types.nullOr nameType;
        default = "oxocarbon-dark";
        description = "Dark base theme name from the CSS or OMP theme catalog. Null leaves the native dark selection unmanaged.";
      };
      light = lib.mkOption {
        type = lib.types.nullOr nameType;
        default = null;
        description = "Light base theme name from the CSS or OMP theme catalog. Null leaves the native light selection unmanaged.";
      };
      palette = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            freeformType = lib.types.attrsOf lib.types.anything;
            options = {
              background = lib.mkOption { type = lib.types.str; };
              foreground = lib.mkOption { type = lib.types.str; };
              cursor_bg = lib.mkOption { type = lib.types.str; };
              ansi = lib.mkOption { type = colors; };
              brights = lib.mkOption { type = colors; };
            };
          }
        );
        default = lib.attrByPath [
          "modules"
          "wezterm"
          "colorSchemes"
          (lib.attrByPath [ "modules" "wezterm" "colorScheme" ] "Oxocarbon Dark" config)
        ] (import ../../theming/_terminal-palette.nix) config;
        description = "WezTerm-format terminal palette applied to each selected appearance. Null preserves the base theme's terminal colors. Defaults to the selected WezTerm scheme or shared Oxocarbon palette.";
      };
      extraCssFiles = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = "CSS files appended in order after the selected base and optional palette in each generated theme. Includes the shared quiet pane grip before normal contributions. Use mkForce to replace the complete list, or mkBefore/mkAfter to order additions. Normal CSS specificity applies.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    modules.tern.theme.extraCssFiles = lib.mkBefore [ ./quiet-grip.css ];
    assertions = [
      {
        assertion = lib.all (
          name: builtins.match "[A-Za-z0-9_-]+" name != null && !(builtins.elem name managedNames)
        ) (builtins.attrNames cfg.themes);
        message = "modules.tern.themes names must contain only letters, digits, underscores or hyphens; nix-managed-dark and nix-managed-light are reserved.";
      }
      {
        assertion = lib.all (name: !(builtins.elem name managedNames)) (builtins.attrValues selected);
        message = "modules.tern.theme.dark/light cannot select reserved nix-managed-dark or nix-managed-light wrappers.";
      }
    ];
    modules.tern.settings = lib.mkIf cfg.theme.enable (
      {
        theme = lib.mkDefault "Dark";
      }
      // lib.mapAttrs' (
        appearance: _: lib.nameValuePair "theme_${appearance}" (lib.mkDefault "nix-managed-${appearance}")
      ) selected
    );
    home.file = lib.mkMerge [
      (lib.mapAttrs' (
        name: asset:
        lib.nameValuePair "${homeRelative}/themes/${name}.css" {
          source = asset.source;
        }
      ) cfg.themes)
      (lib.mkIf cfg.theme.enable (
        lib.mapAttrs' (
          appearance: base:
          lib.nameValuePair "${homeRelative}/themes/nix-managed-${appearance}.css" {
            source = sheet appearance base;
          }
        ) selected
      ))
      {
        ".omp/agent/themes/oxocarbon-dark.json".source =
          lib.mkDefault ../../dev/files/agents/omp/themes/oxocarbon-dark.json;
      }
    ];
  };
}
