{ inputs, ... }:
{
  flake.flakeModules.default = inputs.import-tree ./.;
}
