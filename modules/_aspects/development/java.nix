# Java — from nix-upstream/modules/development/java.nix
{ dl, ... }:
{
  dl.dev-java.homeManager =
    { pkgs, ... }:
    {
      programs.java = {
        enable = true;
        package = pkgs.javaPackages.compiler.openjdk21;
      };

      home.packages = with pkgs; [
        detekt
        maven
      ];
    };
}
