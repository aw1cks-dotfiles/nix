{ ... }:
{
  aw1cks.modules.nixos.latest-kernel-unstable =
    { pkgs, ... }:
    {
      boot.kernelPackages = pkgs.unstable.linuxPackages_latest;
    };
}
