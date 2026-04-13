{ inputs, ... }:
{
  aw1cks.modules = {
    home.nix-index-database = inputs.nix-index-database.homeModules.default;

    # These are only useful if we want to enable nix-index/command-not-found
    # integrations system-wide. Leaving disabled for now.
    # nixos.nix-index-database = inputs.nix-index-database.nixosModules.default;
    # darwin.nix-index-database = inputs.nix-index-database.darwinModules.default;
  };
}
