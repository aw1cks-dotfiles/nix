{ lib, ... }:
{
  flake-file.inputs.nixpkgs-unstable = {
    url = lib.mkDefault "github:NixOS/nixpkgs/nixpkgs-unstable";
  };
}
