{ ... }:
{
  aw1cks.modules.nixos.resolved = {
    networking.networkmanager.dns = "systemd-resolved";
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNSSEC = "allow-downgrade";
        Domains = [ "~." ];
      };
    };
  };
}
