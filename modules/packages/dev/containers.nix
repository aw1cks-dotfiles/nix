# Container tools — from nix-upstream/modules/development/containers.nix
{ lib, ... }:
{
  aw1cks.modules.home.containers =
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          crane
          dive
          skopeo
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          buildah
          containerlab
        ];
    };
}
