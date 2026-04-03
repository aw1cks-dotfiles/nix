# Build-time validation checks
{
  lib,
  config,
  inputs,
  ...
}:
let
  nixosChecks = lib.mapAttrsToList (name: nixos: {
    ${nixos.config.nixpkgs.hostPlatform.system} = {
      "nixos-${name}" = nixos.config.system.build.toplevel;
    };
  }) config.flake.nixosConfigurations;

  # Keep one tiny synthetic Home Manager build per system so flake check still
  # exercises the activation pipeline in CI without depending on any specific
  # real host's package closure. Real desktop and GPU hosts in this repo have
  # very large closures, so building them in CI is disproportionately expensive.
  homeSystems = lib.unique (
    lib.mapAttrsToList (_: { system, ... }: system) config.configurations.home
  );

  homeSmokeChecks = map (
    system:
    let
      smokeHome = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        modules = [
          {
            home = {
              username = "ci";
              homeDirectory = "/build/ci";
              stateVersion = "25.05";
            };

            programs.home-manager.enable = true;
          }
        ];
      };
    in
    {
      ${system}."home-smoke" = smokeHome.activationPackage;
    }
  ) homeSystems;
in
{
  config.flake.checks = lib.mkMerge (nixosChecks ++ homeSmokeChecks);
}
