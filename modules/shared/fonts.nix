{ inputs, lib, ... }:
let
  lucidglyphBase = "${inputs.lucidglyph}/src/modules";

  lucidglyphFontconfigFiles = lib.sort builtins.lessThan (
    builtins.attrNames (
      lib.filterAttrs (name: kind: kind == "regular" && lib.hasSuffix ".conf" name) (
        builtins.readDir "${lucidglyphBase}/fontconfig"
      )
    )
  );

  lucidglyphEnvironment =
    let
      envFiles = lib.sort builtins.lessThan (
        builtins.attrNames (
          lib.filterAttrs (name: kind: kind == "regular" && lib.hasSuffix ".conf" name) (
            builtins.readDir "${lucidglyphBase}/environment"
          )
        )
      );
      parseEnvFile =
        file:
        let
          line = lib.strings.trim (builtins.readFile "${lucidglyphBase}/environment/${file}");
          parsed = builtins.match "^([A-Z0-9_]+)=(.*)$" line;
        in
        if parsed == null then
          throw "Invalid lucidglyph environment file ${file}: expected KEY=VALUE"
        else
          let
            key = builtins.elemAt parsed 0;
            rawValue = builtins.elemAt parsed 1;
            value = lib.removePrefix "\"" (lib.removeSuffix "\"" rawValue);
          in
          lib.nameValuePair key value;
    in
    builtins.listToAttrs (map parseEnvFile envFiles);

in
{
  options.aw1cks.fonts = {
    appleEmoji = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "macos-26-20260219-2aa12422";
      };
      url = lib.mkOption {
        type = lib.types.str;
        default = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260219-2aa12422/AppleColorEmoji-Linux.ttf";
      };
      hash = lib.mkOption {
        type = lib.types.str;
        default = "sha256-U1oEOvBHBtJEcQWeZHRb/IDWYXraLuo0NdxWINwPUxg=";
      };
      family = lib.mkOption {
        type = lib.types.str;
        default = "Apple Color Emoji";
      };
    };

    lucidglyph = {
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = lucidglyphEnvironment;
      };
      fontconfigFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = lucidglyphFontconfigFiles;
      };
    };

    defaults = {
      serif = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "SF Pro Display Nerd Font"
          "SFProDisplay Nerd Font"
          "SF Pro Display"
          "Noto Serif"
          "DejaVu Serif"
        ];
      };
      sansSerif = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "SF Pro Display Nerd Font"
          "SFProDisplay Nerd Font"
          "SF Pro Display"
          "Noto Sans"
          "DejaVu Sans"
        ];
      };
      monospace = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "CaskaydiaMono Nerd Font"
          "CaskaydiaMono NF"
          "Noto Sans Mono"
          "DejaVu Sans Mono"
        ];
      };
    };
  };
}
