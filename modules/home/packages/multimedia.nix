{ config, lib, ... }:
{
  aw1cks.modules.home.multimedia-apps =
    { pkgs, ... }:
    {
      imports = [ config.aw1cks.modules.home.mpv-upscaling ];

      home.packages =
        with pkgs;
        [
          mumble
          qbittorrent
          syncplay
          ytmdesktop
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          playerctl
          pwvucontrol
        ];

      programs = {
        mpv = {
          enable = true;
          # stable mpv does not build on Darwin
          package = pkgs.unstable.mpv;
          defaultProfiles = [
            "high-quality"
          ];
          bindings = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            WHEEL_LEFT = "ignore";
            WHEEL_RIGHT = "ignore";
            # WHEEL_UP = "ignore";
            # WHEEL_DOWN = "ignore";
          };
          config = {
            hwdec = "yes";

            osd-font = "sans-serif";
            sub-color = "#f0f0f0";

            cache = "yes";
            demuxer-max-bytes = "2GiB";
            demuxer-max-back-bytes = "128MiB";
            demuxer-readahead-secs = 240;

            dither = "error-diffusion";
            deband = "yes";
            deband-iterations = 6;
            deband-threshold = 48;
            deband-range = 18;
            deband-grain = 3.0;
          };
        };

        obs-studio.enable = pkgs.stdenv.hostPlatform.isLinux;
        yt-dlp.enable = true;
      };
    };

  aw1cks.modules.home.mpv-upscaling =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.modules.mpv.upscaling;
      inherit (pkgs.stdenv.hostPlatform) isDarwin;

      shaderProfile =
        description: shaders:
        lib.mapAttrs (_: lib.mkDefault) (
          {
            profile-desc = description;
            vo = "gpu-next";
            # Home Manager renders Nix lists as repeated keys, not an mpv path list.
            glsl-shaders = lib.concatStringsSep ":" shaders;
          }
          // lib.optionalAttrs (cfg.gpuApi != null) { gpu-api = cfg.gpuApi; }
          // lib.optionalAttrs (cfg.gpuContext != null) { gpu-context = cfg.gpuContext; }
        );

      artcnn = pkgs.fetchurl {
        name = "ArtCNN_C4F32.glsl";
        url = "https://raw.githubusercontent.com/Artoriuz/ArtCNN/0837e5326e710f49e2ab0a8d995da0708047442e/GLSL/ArtCNN_C4F32.glsl";
        hash = "sha256-93O85s9f5+Xl1Zmmle3UDfXNeiDD0IxNFk0HWR1b6tM=";
      };

      anime4kProfile =
        description: shaders:
        shaderProfile description (map (shader: "${pkgs.anime4k}/Anime4K_${shader}.glsl") shaders);

      modeA =
        model: finalModel: extraPasses:
        [
          "Clamp_Highlights"
          "Restore_CNN_${model}"
          "Upscale_CNN_x2_${model}"
        ]
        ++ extraPasses
        ++ [
          "AutoDownscalePre_x2"
          "AutoDownscalePre_x4"
          "Upscale_CNN_x2_${finalModel}"
        ];
    in
    {
      options.modules.mpv.upscaling = {
        enable = lib.mkEnableOption "opt-in mpv upscaling profiles";
        artcnn.enable = lib.mkEnableOption "the ArtCNN C4F32 mpv profile (anime)" // {
          default = true;
        };
        anime4k.enable = lib.mkEnableOption "the Anime4K mpv profiles" // {
          default = true;
        };

        gpuApi = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = if isDarwin then "vulkan" else null;
          example = "vulkan";
          description = "GPU API for the upscaling profiles. Null leaves the mpv setting unchanged.";
        };

        gpuContext = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = if isDarwin then "macvk" else null;
          example = "macvk";
          description = "GPU context for the upscaling profiles. Null leaves the mpv setting unchanged.";
        };
      };

      config.programs.mpv.profiles = lib.mkIf cfg.enable (
        lib.mkMerge [
          (lib.mkIf cfg.artcnn.enable {
            anime = shaderProfile "Anime upscaling with ArtCNN C4F32" [ "${artcnn}" ];
          })
          (lib.mkIf cfg.anime4k.enable {
            anime4k = anime4kProfile "Anime4K Mode A (Fast)" (modeA "M" "S" [ ]);
            anime4k-l = anime4kProfile "Anime4K Mode A (L models)" (modeA "L" "M" [ ]);
            anime4k-hq = anime4kProfile "Anime4K Mode A (HQ)" (modeA "VL" "M" [ ]);
            anime4k-aa-hq = anime4kProfile "Anime4K Mode A+A (HQ, 2x or greater enlargement)" (
              modeA "VL" "M" [ "Restore_CNN_M" ]
            );
          })
        ]
      );
    };
}
