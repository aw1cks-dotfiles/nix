{ ... }:
{
  aw1cks.modules.nixos.pipewire = {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
      wireplumber.extraConfig."10-usb-dac" = {
        "monitor.alsa.properties" = {
          "alsa.use-acp" = true;
        };

        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "device.name" = "~alsa_card.usb-.*";
              }
            ];
            actions = {
              "update-props" = {
                "api.acp.auto-profile" = true;
                "api.acp.auto-port" = true;
              };
            };
          }
        ];
      };
    };
  };
}
