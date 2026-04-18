{ ... }:
{
  aw1cks.modules.nixos.resolved = {
    networking.networkmanager.dns = "systemd-resolved";
    services.resolved = {
      enable = true;
      dnssec = "allow-downgrade";
      domains = [ "~." ];
    };
  };
}
