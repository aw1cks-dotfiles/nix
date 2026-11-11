{
  perSystem = { pkgs, ... }: {
    packages.kata = import ./_kata/package.nix { inherit pkgs; };
  };
}
