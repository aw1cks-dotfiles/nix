{ inputs, lib, ... }:
{
  flake-file.inputs.agenix = {
    url = lib.mkDefault "github:ryantm/agenix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  # Expose the agenix CLI in perSystem
  perSystem =
    { system, ... }:
    {
      packages.agenix = inputs.agenix.packages.${system}.default;
    };
}
