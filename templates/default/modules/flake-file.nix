{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.default
    inputs.dendritic-lib.flakeModules.downstream-flake-file
  ];

  flake-file = {
    description = "Private Nix configuration — hosts, secrets, and site-specific settings";
    outputs = ''
      inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
          inputs.dendritic-lib.flakeModules.default
          (inputs.import-tree ./modules)
          (inputs.import-tree ./hosts)
        ];
      }
    '';

    inputs = {
      flake-file.url = "github:vic/flake-file";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };

      import-tree.url = "github:vic/import-tree";

      nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

      dendritic-lib = {
        url = "github:aw1cks-dotfiles/nix";
        inputs = {
          flake-parts.follows = "flake-parts";
          import-tree.follows = "import-tree";
          nixpkgs.follows = "nixpkgs";
        };
      };
    };
  };
}
