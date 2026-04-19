{ ... }:
{
  aw1cks.modules.nixos.network = {
    networking = {
      networkmanager.enable = true;

      firewall.enable = true;
      nftables.enable = true;
    };

    boot.initrd.systemd.network.wait-online.enable = false;
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
