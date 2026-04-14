{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";

        settings.global.excludes = [
          # Desktop theme snippets under docs are reference material, not maintained source.
          "docs/desktop/**"

          # Historical reference material kept outside the maintained source tree.
          "nixos-experiments/**"
        ];

        programs = {
          shellcheck.enable = true;
          shfmt.enable = true;
          nixfmt.enable = true;
          taplo.enable = true;
          yamlfmt.enable = true;
          stylua.enable = true;
        };
      };
    };
}
