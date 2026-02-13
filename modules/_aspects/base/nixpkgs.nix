# Nixpkgs configuration and unstable overlay
# Provides the `unstable` package set overlay for accessing bleeding-edge packages
{ dl, inputs, ... }:
{
  dl.base-nixpkgs.homeManager =
    { pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      nixpkgs = {
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          nvidia.acceptLicense = true;
        };
        overlays = [
          (_final: _prev: {
            unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          })
          inputs.claude-code.overlays.default
        ];
      };
    };
}
