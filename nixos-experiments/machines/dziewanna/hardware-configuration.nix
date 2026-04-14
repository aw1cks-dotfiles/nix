# This is configured manually, as the machine is a VM.
{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/core/virtualisation/qemu-guest.nix
  ];
}
