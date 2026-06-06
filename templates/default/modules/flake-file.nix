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
          ./hosts
        ];
      }
    '';

    # Only declare bootstrap inputs the downstream owns directly here.
    # The `dendritic-lib` input itself, plus all reusable shared inputs
    # (agenix, home-manager, lix, …) and their follows are provided by
    # `inputs.dendritic-lib.flakeModules.downstream-flake-file` above.
    # To override, e.g. for a local path checkout:
    #   flake-file.inputs.dendritic-lib.url = "path:../dendritic-lib";
    inputs = {
      flake-file.url = "github:vic/flake-file";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };

      import-tree.url = "github:vic/import-tree";

      nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
    };
  };
}
