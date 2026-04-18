{ config, inputs, ... }:
{
  aw1cks.modules.home.fonts-theme =
    {
      osConfig ? null,
      pkgs,
      ...
    }:
    let
      isStandaloneHome = osConfig == null;
      lucidglyphBase = "${inputs.lucidglyph}/src/modules/fontconfig";
      lucidglyphConfigFiles = builtins.listToAttrs (
        map (file: {
          name = "lucidglyph-${file}";
          value = {
            enable = true;
            priority = builtins.fromJSON (builtins.substring 0 2 file);
            source = "${lucidglyphBase}/${file}";
          };
        }) config.aw1cks.fonts.lucidglyph.fontconfigFiles
      );

      appleEmoji = pkgs.stdenvNoCC.mkDerivation {
        pname = "apple-color-emoji-linux";
        version = config.aw1cks.fonts.appleEmoji.version;
        src = pkgs.fetchurl {
          inherit (config.aw1cks.fonts.appleEmoji) url hash;
        };
        dontUnpack = true;
        installPhase = ''
          install -Dm644 "$src" "$out/share/fonts/truetype/AppleColorEmoji-Linux.ttf"
        '';
      };
    in
    {
      home.packages = [
        inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
      ]
      ++ pkgs.lib.optionals (pkgs.stdenv.isLinux && isStandaloneHome) [ appleEmoji ];

      fonts.fontconfig = {
        enable = true;
        configFile = lucidglyphConfigFiles;
        defaultFonts.emoji = [ config.aw1cks.fonts.appleEmoji.family ];
        defaultFonts.serif = config.aw1cks.fonts.defaults.serif;
        defaultFonts.sansSerif = config.aw1cks.fonts.defaults.sansSerif;
        defaultFonts.monospace = config.aw1cks.fonts.defaults.monospace;
      };
    };
}
