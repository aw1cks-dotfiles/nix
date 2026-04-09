{ lib, inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isDarwin {
      apps.darwin = {
        type = "app";
        program = "${inputs.nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild";
        meta.description = "Run nix-darwin's darwin-rebuild from this flake's pinned input";
      };
    };
}
