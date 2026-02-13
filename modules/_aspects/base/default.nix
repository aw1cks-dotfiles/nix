# Base composite aspect — includes all base sub-aspects
{ dl, den, ... }:
{
  dl.base = {
    includes = [
      dl.base-nixpkgs
      dl.base-home-manager
      dl.base-nix-settings
      dl.base-cli-tools
      dl.base-git
    ];
  };
}
