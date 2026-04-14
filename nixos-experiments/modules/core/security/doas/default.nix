{ pkgs, ... }:
{
  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [{
      groups = [ "wheel" ];
      keepEnv = true;
      noPass = true;
    }];
  };

  environment.systemPackages = [ pkgs.doas-sudo-shim ];
}
