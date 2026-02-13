{ inputs, ... }:
{
  imports = [ ./_den.nix ];
  # Note: _den.nix is imported above AND will be included in the flakeModule below.
  # The double import is intentional - _den.nix is needed both in this flake
  # and in consuming flakes via flakeModules.default
  flake.flakeModules.default = inputs.import-tree ./.;
}
