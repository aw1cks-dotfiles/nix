# Inspired by https://github.com/mitchellh/nixos-config/blob/88f305ebd02c88451b7f280082d4f4bf9a6142c8/lib/mksystem.nix
{ nixpkgs, inputs }:

name:
{
  system,
  user,
  disko ? false,
  homeManager ? false,
  isVmBuild ? false
}:

let
  machineConfig = ../../machines/${name}/configuration.nix;
  userOSConfig  = ../../users/${user}/nixos.nix;
  userHMConfig  = ../../users/${user}/home-manager.nix;

in nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = { inherit inputs isVmBuild; };

  modules = [
    { nixpkgs.config.allowUnfree = true; }

    ./system-facts.nix

    machineConfig
    userOSConfig
  ] ++ nixpkgs.lib.optional homeManager (
    inputs.home-manager.nixosModules.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${user} = import userHMConfig {
        inherit inputs;
      };
    }
  )
  ++ nixpkgs.lib.optional disko inputs.disko.nixosModules.disko;
}
