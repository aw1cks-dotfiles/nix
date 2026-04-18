{ ... }:
{
  aw1cks.modules.nixos.boot = {
    boot = {
      loader.timeout = 0;
      bootspec.enable = true;

      initrd = {
        verbose = false;
        systemd.enable = true;
      };

      tmp.cleanOnBoot = true;
    };
  };
}
