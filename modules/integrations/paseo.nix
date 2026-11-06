{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      paseo = import ./_paseo-package.nix {
        inherit pkgs;
        paseoInput = inputs.paseo;
      };
      withPassword = import ./_paseo-with-password.nix { inherit pkgs; };
    in
    {
      packages = {
        inherit paseo;
        paseo-omp-plugin = import ./_paseo-omp-package.nix { inherit pkgs; };
        paseo-with-password = withPassword;
      };
      checks.paseo-state =
        pkgs.runCommand "paseo-private-state"
          {
            nativeBuildInputs = [ pkgs.nodejs_22 ];
            PASEO_SERVER_DIRECTORY = "${paseo}/lib/paseo/packages/server/dist/server/server";
            PASEO_PASSWORD_COMMAND = lib.getExe withPassword;
          }
          ''
            node --test ${../home/dev/files/paseo}/prepare.test.mjs
            touch "$out"
          '';
    };
}
