# Java — from nix-upstream/modules/development/java.nix
{ ... }:
{
  flake.modules.home.java =
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
