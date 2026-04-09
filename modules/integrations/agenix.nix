{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages.agenix = inputs.agenix.packages.${system}.default;
    };
}
