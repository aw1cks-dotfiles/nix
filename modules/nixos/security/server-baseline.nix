{ lib, ... }:
{
  aw1cks.modules.nixos.server-security = {
    users.mutableUsers = false;

    services.openssh = {
      enable = true;
      ports = [ 222 ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    services.endlessh = {
      enable = true;
      port = 22;
      openFirewall = true;
    };
  };
}
