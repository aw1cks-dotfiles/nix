# Build-time validation checks
{ lib, config, ... }:
{
  config.flake.checks = lib.mkMerge (
    lib.mapAttrsToList (name: nixos: {
      ${nixos.config.nixpkgs.hostPlatform.system} = {
        "nixos-${name}" = nixos.config.system.build.toplevel;
      };
    }) config.flake.nixosConfigurations
  );
}
