{ inputs, ... }:
{
  flake.flakeModules = {
    downstream-flake-file = ./_internal/flake-file-inputs;
    default = {
      imports = [
        ./_schema/host-facts.nix
        ./_schema/home-nvidia-configurations.nix
        ./_schema/identity.nix
        (inputs.import-tree ./.)
        ./_internal/flake-file-inputs
      ];
    };
  };
}
