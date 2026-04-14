{ pkgs, config, ... }:
{

  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  # TODO: Set up proper split horizon DNS with resolved
  # TODO: full declarative NetworkManager
  # TODO: unbound/pdns-recursor stub DNS, DoT/DoH, split horizon
  # TODO: openresolv or similar (integrate to stub resolver)

  networking.firewall.enable = true;
  networking.nftables.enable = true;
}
