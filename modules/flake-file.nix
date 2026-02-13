{ inputs, lib, ... }:
{
  imports = [ inputs.flake-file.flakeModules.default ];

  flake-file = {
    description = lib.mkDefault "Dendritic Nix library — reusable NixOS, home-manager, and nix-darwin modules";
    outputs = lib.mkDefault "inputs: import ./outputs.nix inputs";

    inputs = {
      flake-file.url = "github:vic/flake-file";

      flake-parts.url = "github:hercules-ci/flake-parts";
      flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

      import-tree.url = "github:vic/import-tree";

      nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    };
  };
}
