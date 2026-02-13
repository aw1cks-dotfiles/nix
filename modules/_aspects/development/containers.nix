# Container tools — from nix-upstream/modules/development/containers.nix
{ dl, ... }:
{
  dl.dev-containers.homeManager =
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
