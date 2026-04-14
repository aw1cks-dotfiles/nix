{ pkgs, ... }:
{
  users.mutableUsers = false;

  services.openssh = {
    enable = true;
    ports = [ 222 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "alex" ];
      # TODO: consider https://man.openbsd.org/sshd_config.5#PerSourcePenalties
    };
  };
  # SSH tarpit
  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
  };

  imports = [
    ./doas
  ];
}
