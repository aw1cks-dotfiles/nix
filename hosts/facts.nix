{ lib, ... }:
{
  options.flake.hostFacts = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Normalized shared host metadata used by constructors and host modules.";
  };

  config.flake.hostFacts = import ./_facts.nix;
}
