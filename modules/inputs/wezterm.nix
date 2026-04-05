{ lib, ... }:
{
  flake-file.inputs.wezterm = {
    url = lib.mkDefault "github:wezterm/wezterm?dir=nix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };
}
