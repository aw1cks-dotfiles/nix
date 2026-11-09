{ ... }:
{
  aw1cks.modules.darwin.homebrew = {
    security.pam.services.sudo_local.touchIdAuth = true;

    homebrew = {
      enable = true;
      onActivation.cleanup = "zap";
      casks = [
        "calibre"
        "crystalfetch"
        "microsoft-auto-update"
        "microsoft-remote-desktop"
        "omnissa-horizon-client"
        "openmtp"
        "openvpn-connect"
        "tailscale-app"
        "tunnelblick"
        "whatsapp"
        "ytmdesktop-youtube-music"
        "zoom"
      ];
    };
  };
}
