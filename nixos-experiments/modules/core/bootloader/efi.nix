{ pkgs, ... }:
{
  boot.loader.efi.canTouchEfiVariables = true;
}
