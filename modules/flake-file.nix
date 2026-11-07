{ inputs, lib, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.default
    ./_internal/flake-file-inputs
  ];

  flake.flakeModules = {
    downstream-flake-file = {
      imports = [
        # Shared transitive inputs (agenix, home-manager, lix, …)
        ./_internal/flake-file-inputs
        # Auto-generated `dendritic-lib` input + follows for every shared and
        # bootstrap input. Downstreams should NOT redeclare `dendritic-lib`
        # manually unless they are intentionally overriding the contract.
        ./_internal/downstream-dendritic-input.nix
      ];
    };
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

    # Repo-local only: consumers of flakeModules.default need no templates tree.
    check-files = [
      "flake.nix"
      "flake.lock"
    ];

    inputs = {
      # Keep only the repo bootstrap inputs here.
      # Reusable downstream contract inputs live in ./_internal/flake-file-inputs.
      nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
      nixos-anywhere = {
        url = "github:nix-community/nixos-anywhere";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      noctalia = {
        # TODO: migrate the desktop host to Noctalia v5's new TOML configuration.
        url = "github:noctalia-dev/noctalia/legacy-v4";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };
      # Keep the installer image paired with upstream's compatible nixpkgs pin.
      # Newer nixpkgs can remove options still used by its boot modules.
      nixos-images.url = "github:nix-community/nixos-images";
      nix-vm-test = {
        url = "github:numtide/nix-vm-test";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };
      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
      flake-file.url = "github:denful/flake-file";
      import-tree.url = "github:denful/import-tree";
    };
  };
}
