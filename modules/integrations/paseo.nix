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
      checks.paseo-state =
        pkgs.runCommand "paseo-private-state"
          {
            nativeBuildInputs = [ pkgs.nodejs_22 ];
            PASEO_AUTH_MODULE = "${paseo}/lib/paseo/packages/server/dist/server/server/auth.js";
          }
          ''
            node --test ${../home/dev/files/paseo}/prepare.test.mjs
            touch "$out"
          '';
    };
}
