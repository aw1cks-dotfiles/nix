# Public reusable transitive inputs for downstream flakes.
#
# The actual input definitions live in ./_inputs.nix as plain data so that
# ../downstream-dendritic-input.nix can introspect their attribute names and
# auto-generate follows for the dendritic-lib input itself. Keep this file
# minimal — add inputs in ./_inputs.nix.
{ lib, ... }:
{
  flake-file.inputs = import ./_inputs.nix { inherit lib; };
}
