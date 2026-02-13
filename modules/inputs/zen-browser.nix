{ lib, ... }:
{
  flake-file.inputs.zen-browser = {
    url = lib.mkDefault "github:0xc000022070/zen-browser-flake";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };
}
