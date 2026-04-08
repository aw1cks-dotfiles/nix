{ lib, ... }:
{
  flake-file.inputs.zen-browser = {
    url = lib.mkDefault "github:0xc000022070/zen-browser-flake";
    inputs ={
      home-manager.follows = lib.mkDefault "home-manager";
      nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
    };
  };
}
