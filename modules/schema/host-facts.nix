{ lib, ... }:
{
  options.aw1cks.hostFacts = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Normalized shared host metadata used by constructors and host modules.";
  };
}
