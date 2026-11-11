{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      # This explicit package is unfree. Keep the exception scoped to Tern;
      # the private artifact still has to be supplied through requireFile.
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = package: lib.getName package == "tern";
      };
    in
    {
      packages.tern = import ./_tern-package.nix { inherit pkgs; };
      # Do not alias this to a flake check: public CI has no authenticated
      # source archives and must not redistribute the closed-beta application.
    };
}
