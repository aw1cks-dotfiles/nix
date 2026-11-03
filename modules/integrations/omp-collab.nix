{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.omp-collab = import ./_omp-collab-package.nix {
        inherit pkgs;
        ompInput = inputs.oh-my-pi;
      };
    };
}
