{ lib, inputs, ... }:
{
  flake-file.inputs.nix-darwin = {
    url = lib.mkDefault "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  perSystem =
    { system, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isDarwin {
      apps.darwin = {
        type = "app";
        program = "${inputs.nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
      };
    };
}
