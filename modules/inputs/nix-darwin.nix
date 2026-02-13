{ lib, ... }:
{
  flake-file.inputs.nix-darwin = {
    url = lib.mkDefault "github:LnL7/nix-darwin";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };
}
