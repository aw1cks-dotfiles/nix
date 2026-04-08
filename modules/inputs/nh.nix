{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      apps.nh = {
        type = "app";
        program = "${pkgs.nh}/bin/nh";
        meta.description = "Run the NH CLI from this flake's pinned nixpkgs package";
      };
    };
}
