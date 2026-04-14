{ config, lib, pkgs, ... }:
let
  ipv4Addr = "188.34.202.238";
  ipv4Cidr = "32";

  ipv6Addr = "2a01:4f8:c2c:72ef::";
  ipv6Cidr = "64";
in
{
  networking.hostName = "dazhbog";
  networking.domain   = "pub.awicks.io";

  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "1.1.1.1"
    "2606:4700:4700::1111"
    "8.8.8.8"
    "2001:4860:4860::8888"
  ];
  networking.hosts = lib.optionalAttrs (!config.my.system.isVmBuild) {
    "${ipv4Addr}" = [ "${config.networking.hostName}.${config.networking.domain}" config.networking.hostName ];
    "${ipv6Addr}1" = [ "${config.networking.hostName}.${config.networking.domain}" config.networking.hostName ];
  };

  networking.useDHCP = false;
  networking.dhcpcd.enable = false;
  networking.networkmanager.settings = {
    main = {
      no-auto-default = "*";
    };
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
          interface-name = "enp1s0";
          autoconnect-priority = "100";
        };
        ethernet = {};
        ipv4 = {
          method = "manual";
          address1 = "${ipv4Addr}/${ipv4Cidr},172.31.1.1";
          route1 = "172.31.1.1";
        };
        ipv6 = {
          method = "manual";
          address1 = "${ipv6Addr}/${ipv6Cidr},fe80::1";
          route1 = "::/0,fe80::1";
        };
      };
    })
  ];
}
