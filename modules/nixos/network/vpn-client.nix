{ ... }:
{
  aw1cks.modules.nixos.vpn-client =
    { config, pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        networkmanagerapplet
        openvpn
      ];
      networking = {
        firewall = {
          allowedUDPPorts = [ config.services.tailscale.port ];
          # needed so exit nodes work
          checkReversePath = "loose";
          trustedInterfaces = [ "tailscale0" ];
        };
        networkmanager.plugins = with pkgs; [
          networkmanager-openvpn
        ];
      };
      services.tailscale.enable = true;
      systemd.services.tailscaled.serviceConfig.Environment = [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];
    };
}
