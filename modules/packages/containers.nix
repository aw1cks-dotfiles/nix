# Container tools — from nix-upstream/modules/development/containers.nix
{ ... }:
{
  flake.modules.home.containers =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        buildah
        containerlab
        crane
        dive
        skopeo
      ];
    };
}
