{ ... }:
{
  aw1cks.modules.nixos.systemd-boot = {
    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
  };
}
