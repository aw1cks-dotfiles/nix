{ lib, inputs, ... }:
{
  flake-file.inputs.lix = {
    url = lib.mkDefault "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
    flake = false;
  };

  flake-file.inputs.lix-module = {
    url = lib.mkDefault "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
    inputs.lix.follows = lib.mkDefault "lix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  flake.modules = {
    nixos.lix = inputs.lix-module.nixosModules.default;
    darwin.lix = inputs.lix-module.darwinModules.default;
  };
}
