{ inputs, lib, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.default
    ./_internal/flake-file-inputs
  ];

  flake.flakeModules = {
    downstream-flake-file = ./_internal/flake-file-inputs;
    default = {
      # Keep repo-local flake-file wiring out of the reusable downstream module surface.
      disabledModules = [ ./flake-file.nix ];
      imports = [
        (inputs.import-tree ./.)
        ./_internal/flake-file-inputs
      ];
    };
  };

  flake.templates.default = {
    path = ../templates/default;
    description = "Starter downstream flake using dendritic-lib";
  };

  perSystem = {
    apps = {
      write-inputs.meta.description = "Regenerate flake inputs from the flake-file source";
      write-lock.meta.description = "Regenerate the flake lockfile from the flake-file source";
      write-flake.meta.description = "Regenerate the generated flake.nix from the flake-file source";
    };
  };

  flake-file = {
    description = lib.mkDefault "Dendritic Nix library — reusable NixOS, home-manager, and nix-darwin modules";
    outputs = lib.mkDefault ''
      inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [
          (inputs.import-tree ./modules)
          ./hosts
          ./modules/_internal/flake-file-inputs
        ];
      }
    '';

    inputs = {
      # Keep only the repo bootstrap inputs here.
      # Reusable downstream contract inputs live in ./_internal/flake-file-inputs.
      nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
      nixos-anywhere = {
        url = "github:nix-community/nixos-anywhere";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      nixos-images = {
        url = "github:nix-community/nixos-images";
        inputs.nixos-unstable.follows = "nixpkgs-unstable";
      };
      nix-vm-test = {
        url = "github:Enzime/nix-vm-test/pr-105-latest";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };
      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
      flake-file.url = "github:vic/flake-file";
      import-tree.url = "github:vic/import-tree";
    };
  };
}
