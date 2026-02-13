# Wire den into dendritic-lib, expose aspects under "dl" namespace
{ inputs, lib, ... }:
{
  imports = lib.optionals (inputs ? den) [
    (inputs.den.flakeModules.dendritic or { })
    (inputs.den.namespace "dl" true)
    # Import aspects after namespace is created
    ./_aspects.nix
  ];
}
