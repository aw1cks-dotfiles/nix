{ inputs, ... }:
{
  flake.flakeModules = {
    downstream-flake-file = ./_internal/flake-file-inputs;
    default = {
      imports = [
        (inputs.import-tree ./.)
        ./_internal/flake-file-inputs
      ];
    };
  };
}
