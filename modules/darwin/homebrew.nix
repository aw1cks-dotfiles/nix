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
        "mactex"
        "microsoft-auto-update"
        "microsoft-remote-desktop"
        "microsoft-teams"
        "omnissa-horizon-client"
        "openmtp"
        "openvpn-connect"
        "tailscale-app"
        "whatsapp"
        "ytmdesktop-youtube-music"
      ];
    };
  };
}
