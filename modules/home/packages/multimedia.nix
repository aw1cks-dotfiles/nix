{ ... }:
{
  aw1cks.modules.home.multimedia-apps =
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          mumble
          qbittorrent
          syncplay
          ytmdesktop
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          playerctl
        ];

      programs = {
        mpv = {
          enable = true;
          # stable mpv does not build on Darwin
          package = pkgs.unstable.mpv;
          defaultProfiles = [
            "high-quality"
          ];
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

        obs-studio.enable = pkgs.stdenv.isLinux;
        yt-dlp.enable = true;
      };
    };
}
