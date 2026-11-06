{ inputs, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      packages.omp-collab = import ./_omp-collab-package.nix {
        inherit pkgs;
        ompInput = inputs.oh-my-pi;
      };
      # Host evaluation alone does not exercise the bundle or install phases.
      checks.omp-collab = config.packages.omp-collab;
    };
}
