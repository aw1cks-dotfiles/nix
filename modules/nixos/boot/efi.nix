{ ... }:
{
  aw1cks.modules.nixos.efi = {
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
