{ inputs, lib, ... }:
{
  flake-file.inputs.home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  # Expose home-manager CLI as the default app
  perSystem =
    { system, ... }:
    {
      apps.default = {
        type = "app";
        program = "${inputs.home-manager.packages.${system}.home-manager}/bin/home-manager";
      };
    };
}
