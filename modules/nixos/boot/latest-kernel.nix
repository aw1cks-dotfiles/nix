{ pkgs, ... }:
{
  aw1cks.modules.nixos.latest-kernel = {
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
