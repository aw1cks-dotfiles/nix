{ config, lib, pkgs, ... }:
let
  ipv4Addr = "41.215.240.83";
  ipv4Cidr = "24";

  ipv6Addr = "2a05:300:1:1::6f8";
  ipv6Cidr = "125";
in
{
  networking.hostName = "dziewanna";
  networking.domain = "pub.awicks.io";

  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "1.1.1.1"
    "2606:4700:4700::1111"
    "8.8.8.8"
    "2001:4860:4860::8888"
  ];
  networking.hosts = lib.optionalAttrs (!config.my.system.isVmBuild) {
    "${ipv4Addr}" = [ "${config.networking.hostName}.${config.networking.domain}" config.networking.hostName ];
    "${ipv6Addr}" = [ "${config.networking.hostName}.${config.networking.domain}" config.networking.hostName ];
  };

  networking.networkmanager.ensureProfiles.profiles = lib.mkMerge [
    (lib.mkIf config.my.system.isVmBuild {
      qemu = {
        connection = {
          id = "qemu";
          type = "ethernet";
          interface-name = "enp1s0";
          autoconnect-priority = "100";
        };
        ethernet = {};
        ipv4 = {
          method = "auto";
        };
      };
    })
    (lib.mkIf (!config.my.system.isVmBuild) {
      wan = {
        connection = {
          id = "wan";
          type = "ethernet";
          autoconnect-priority = "100";
        };
        ethernet = {
          mac-address = "52:54:00:ed:9f:52";
          mtu = "1400";
        };
        ipv4 = {
          method = "manual";
          addresses = "${ipv4Addr}/${ipv4Cidr}";
          gateway = "41.215.240.254";
          route-data = "41.215.240.254/32,0.0.0.0,0";
        };
        ipv6 = {
          method = "manual";
          addresses = "${ipv6Addr}/${ipv6Cidr}";
          gateway = "2a05:300:1:1::1";
          route-data = "2a05:300:1:1::1/128,::0,0";
        };
      };
    })
  ];
}
