{ inputs, ... }:
{
  flake.modules = {
    nixos.lix = inputs.lix-module.nixosModules.default;
    darwin.lix = inputs.lix-module.darwinModules.default;
  };
}
