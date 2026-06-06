# Auto-generate the `dendritic-lib` flake input for downstream consumers.
#
# Only imported via `flake.flakeModules.downstream-flake-file`. Never loaded by
# upstream's own flake (it cannot declare itself as an input).
#
# Generates `flake-file.inputs.dendritic-lib = { url; inputs.<X>.follows = "<X>"; }`
# for every input the downstream is expected to provide at the top level:
#
#   - all shared inputs from ./flake-file-inputs/_inputs.nix (auto-extended
#     whenever a new shared input is added — the original motivation for this
#     module)
#   - a small bootstrap list every downstream flake-file source declares
#     directly (flake-file, flake-parts, import-tree, nixpkgs)
#
# All values use `lib.mkDefault`, so a downstream can override the URL or
# extend the follows set (for example, to follow inputs that live only in
# dendritic-lib's own flake-file like `nixos-anywhere`):
#
#   flake-file.inputs.dendritic-lib = {
#     url = "path:/abs/path/to/local/checkout";   # local override
#     inputs.nixos-anywhere.follows = "nixos-anywhere";
#   };
{ lib, ... }:
let
  sharedInputs = import ./flake-file-inputs/_inputs.nix { inherit lib; };

  # Inputs every downstream flake-file source is expected to declare directly.
  # Keeping this list narrow avoids generating follows that would fail to
  # resolve in a minimal downstream that doesn't redeclare optional inputs.
  bootstrapFollows = [
    "flake-file"
    "flake-parts"
    "import-tree"
    "nixpkgs"
  ];

  followNames = bootstrapFollows ++ builtins.attrNames sharedInputs;

  mkFollow = name: {
    inherit name;
    value.follows = lib.mkDefault name;
  };
in
{
  flake-file.inputs.dendritic-lib = {
    url = lib.mkDefault "github:aw1cks-dotfiles/nix";
    inputs = builtins.listToAttrs (map mkFollow followNames);
  };
}
