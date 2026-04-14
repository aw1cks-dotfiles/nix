{ ... }:
{
  aw1cks.modules.nixos.network = {
    networking.networkmanager.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;

    networking.firewall.enable = true;
    networking.nftables.enable = true;
  };
}
