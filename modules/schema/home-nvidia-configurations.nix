{ lib, ... }:
{
  options.aw1cks.homeNvidiaConfigurations = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Derived standalone Home Manager NVIDIA host metadata for updater tooling.";
  };
}
