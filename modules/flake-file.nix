{ inputs, lib, ... }:
{
  imports = [ inputs.flake-file.flakeModules.default ];

  flake-file = {
    description = lib.mkDefault "Dendritic Nix library — reusable NixOS, home-manager, and nix-darwin modules";
    outputs = lib.mkDefault "inputs: import ./outputs.nix inputs";

    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
      flake-file.url = "github:vic/flake-file";
      import-tree.url = "github:vic/import-tree";
    };
  };
}
