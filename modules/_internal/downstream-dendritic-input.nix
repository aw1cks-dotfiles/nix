# Auto-generate downstream `dendritic-lib` follows and reviewed skill defaults.
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
# The library URL and follows use `lib.mkDefault`, so a downstream can override
# them or extend the follows set (for example, to follow inputs that live only
# in dendritic-lib's own flake-file like `nixos-anywhere`):
#
#   flake-file.inputs.dendritic-lib = {
#     url = "path:/abs/path/to/local/checkout";   # local override
#     inputs.nixos-anywhere.follows = "nixos-anywhere";
#   };
{ lib, ... }:
let
  sharedInputs = import ./flake-file-inputs/_inputs.nix { inherit lib; };

  # Project this checkout's reviewed lock into downstream declarations only.
  # Root URLs stay floating so Renovate can continue proposing lock updates.
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  skillInputs = builtins.attrNames (
    builtins.fromJSON (builtins.readFile ../../.github/skill-inputs.json)
  );
  skillDefaults = lib.genAttrs skillInputs (
    name:
    let
      locked = lock.nodes.${lock.nodes.${lock.root}.inputs.${name}}.locked;
    in
    {
      # Beat the shared floating mkDefault (1000), not caller definitions (100).
      url = lib.mkOverride 900 "github:${locked.owner}/${locked.repo}/${locked.rev}";
    }
  );

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
  flake-file.inputs = skillDefaults // {
    dendritic-lib = {
      url = lib.mkDefault "github:aw1cks-dotfiles/nix";
      inputs = builtins.listToAttrs (map mkFollow followNames);
    };
  };
}
