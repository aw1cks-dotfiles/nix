{ lib, ... }:
{
  # Let nix-manipulator use its own pinned nixpkgs — it depends on a fork
  # with specific tree-sitter/tree-sitter-nix versions.
  flake-file.inputs.nix-manipulator.url = lib.mkDefault "github:hoh/nix-manipulator";
}
