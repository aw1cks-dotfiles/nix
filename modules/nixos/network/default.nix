{ ... }:
{
  aw1cks.modules.nixos.network = {
    networking = {
      networkmanager.enable = true;

      firewall.enable = true;
      nftables.enable = true;
    };

    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
