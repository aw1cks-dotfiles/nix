{
  config,
  inputs,
  lib,
  ...
}:
{
  aw1cks.modules.home.kata = ./_kata/service.nix;

  perSystem = { pkgs, ... }: {
    packages.kata = import ./_kata/package.nix { inherit pkgs; };
    checks.kata = import ./_kata/checks.nix {
      inherit inputs lib pkgs;
      kataModule = config.aw1cks.modules.home.kata;
    };
  };
}
