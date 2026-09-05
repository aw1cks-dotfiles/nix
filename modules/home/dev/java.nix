# Java — from nix-upstream/modules/development/java.nix
{ ... }:
{
  aw1cks.modules.home.java =
    { pkgs, ... }:
    {
      programs.java = {
        enable = true;
        package = pkgs.javaPackages.compiler.openjdk21;
      };

      # Maven 3.9+ prepends MAVEN_ARGS to every invocation while still allowing
      # project and command-line arguments to follow.
      home.sessionVariables.MAVEN_ARGS = "-Dmaven.artifact.threads=16 -Daether.dependencyCollector.impl=bf -Daether.dependencyCollector.bf.threads=16";

      home.packages = with pkgs; [
        detekt
        maven
      ];
    };
}
