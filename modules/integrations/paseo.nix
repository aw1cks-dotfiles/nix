{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      paseo = import ./_paseo-package.nix {
        inherit pkgs;
        paseoInput = inputs.paseo;
      };
    in
    {
      packages = {
        inherit paseo;
        paseo-omp-plugin = import ./_paseo-omp-package.nix { inherit pkgs; };
      };
    };
}
