{ lib, ... }:
{
  # Sensible default kernel for any host: latest stable kernel from the
  # pinned nixpkgs channel. Set with lib.mkDefault so a host (or a more
  # specific profile like desktop-perf with its CachyOS kernel) can
  # override boot.kernelPackages with a plain assignment.
  aw1cks.modules.nixos.latest-kernel =
    { pkgs, ... }:
    {
      boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    };
}
