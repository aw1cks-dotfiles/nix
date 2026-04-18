{ ... }:
{
  aw1cks.modules.nixos.vpn-client =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        networkmanagerapplet
        openvpn
      ];
      networking.networkmanager.plugins = with pkgs; [
        networkmanager-openvpn
      ];
    };
}
