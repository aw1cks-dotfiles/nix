{ lib, inputs, ... }:
{
  perSystem =
    { system, ... }:
    lib.mkIf (inputs ? nixos-anywhere && builtins.hasAttr system inputs.nixos-anywhere.packages) {
      packages.nixos-anywhere = inputs.nixos-anywhere.packages.${system}.default;

      apps.nixos-anywhere = {
        type = "app";
        program = "${inputs.nixos-anywhere.packages.${system}.default}/bin/nixos-anywhere";
        meta.description = "Run nixos-anywhere from this flake's pinned input";
      };
    };
}
