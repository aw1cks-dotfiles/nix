{ lib, ... }:
let
  inherit (import ./_sources.nix) artifacts;
  supported = pkgs: builtins.hasAttr pkgs.stdenv.hostPlatform.system artifacts;
  package = pkgs: import ./_package.nix { inherit pkgs; };
in
{
  perSystem =
    { pkgs, ... }:
    lib.mkIf (supported pkgs) {
      packages.learnharness = package pkgs;
    };

  aw1cks.modules.home.learnharness =
    { config, pkgs, ... }:
    {
      options.modules.learnharness.enable = lib.mkEnableOption "the upstream LearnHarness desktop app";

      config = lib.mkIf config.modules.learnharness.enable {
        assertions = [
          {
            assertion = supported pkgs;
            message = "LearnHarness publishes desktop binaries only for Apple Silicon macOS and x86-64 Linux.";
          }
        ];
        home.packages = lib.optional (supported pkgs) (package pkgs);
      };
    };
}
