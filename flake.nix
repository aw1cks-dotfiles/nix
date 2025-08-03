{
  description = "aw1cks home-manager configuration";
  inputs = {
    nixpkgs.url = "nixpkgs/release-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixgl = {
      # Using a patched version, see https://github.com/nix-community/nixGL/pull/187
      # url = "github:nix-community/nixGL"
      url = "github:phirsch/nixGL/fix-versionMatch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, nixgl, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      overlay-unstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay-unstable ];
      };
    in {
      homeConfigurations = {
        alex = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix];
          extraSpecialArgs = {
            nixgl = nixgl;
          };
        };
      };
    };
}
