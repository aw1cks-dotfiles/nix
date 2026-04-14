{ pkgs, ... }:
{
  services.displayManager.ly = {
    enable = true;
    settings = {
      load = true;
      save = true;
      clear_password = true;
      shutdown_cmd = "/run/current-system/sw/bin/systemctl poweroff";
      restart_cmd = "/run/current-system/sw/bin/systemctl reboot";
    };
  };
}
