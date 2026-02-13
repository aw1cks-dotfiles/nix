{ lib, ... }:
{
  flake-file.inputs.stylix = {
    url = lib.mkDefault "github:nix-community/stylix/release-25.11";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };
}
