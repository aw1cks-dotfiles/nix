{ config, inputs, ... }:
{
  aw1cks.modules.nixos.fonts =
    { pkgs, ... }:
    let
      lucidglyphBase = "${inputs.lucidglyph}/src/modules/fontconfig";
      lucidglyphFontconfig = pkgs.symlinkJoin {
        name = "lucidglyph-fontconfig";
        paths = [
          (pkgs.runCommandLocal "lucidglyph-fontconfig-conf" { } ''
            mkdir -p "$out/etc/fonts/conf.d"
            ${pkgs.lib.concatMapStringsSep "\n" (
              file: "install -Dm644 ${lucidglyphBase}/${file} \"$out/etc/fonts/conf.d/${file}\""
            ) config.aw1cks.fonts.lucidglyph.fontconfigFiles}
          '')
        ];
      };

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
      environment.variables = config.aw1cks.fonts.lucidglyph.environment;
      programs.dconf.enable = true;

      fonts = {
        packages = [
          inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
          appleEmoji
        ];

        fontconfig = {
          enable = true;
          confPackages = [ lucidglyphFontconfig ];
          defaultFonts.emoji = [ config.aw1cks.fonts.appleEmoji.family ];
          defaultFonts.serif = config.aw1cks.fonts.defaults.serif;
          defaultFonts.sansSerif = config.aw1cks.fonts.defaults.sansSerif;
          defaultFonts.monospace = config.aw1cks.fonts.defaults.monospace;
        };
      };
    };
}
