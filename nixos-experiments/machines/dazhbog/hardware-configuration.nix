# This is configured manually, as the machine is a VM.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    ../../modules/core/virtualisation/qemu-guest.nix
    ../../modules/core/network
  ];

  # https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Cloud#AArch64_(CAX_instance_type)_specifics
  boot.initrd.kernelModules = [ "virtio_gpu" ];
  boot.kernelParams =
    if config.my.system.isVmBuild then [ "console=tty0" "console=ttyS0" ] else [ "console=tty" ];

  /*
  zramSwap = {
    enable = true;
  }
  */
}
