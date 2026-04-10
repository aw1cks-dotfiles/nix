{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";

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
