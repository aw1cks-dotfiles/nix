# Build-time validation checks
{
  lib,
  config,
  inputs,
  ...
}:
let
  mergeChecks = checks: builtins.foldl' (acc: next: acc // next) { } checks;

  mkPerSystemCheck =
    {
      system,
      name,
      value,
    }:
    {
      ${system}.${name} = value;
    };

  nixosChecks = lib.mapAttrsToList (name: nixos: {
    ${nixos.config.nixpkgs.hostPlatform.system} =
      (mkPerSystemCheck {
        system = nixos.config.nixpkgs.hostPlatform.system;
        name = "nixos-${name}";
        value = nixos.config.system.build.toplevel;
      }).${nixos.config.nixpkgs.hostPlatform.system};
  }) config.flake.nixosConfigurations;

  darwinChecks = lib.mapAttrsToList (
    name: darwin:
    let
      system = darwin.config.nixpkgs.hostPlatform.system;
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      user = darwin.config.system.primaryUser;
      hmUsers = darwin.config.home-manager.users or { };
      hasHmUser = user != null && builtins.hasAttr user hmUsers;
      hmUser = lib.attrByPath [ user ] null hmUsers;
      homeUser = if hasHmUser then hmUser.home.username else "";
      homeDir = if hasHmUser then toString hmUser.home.homeDirectory else "";
    in
    mkPerSystemCheck {
      inherit system;
      name = "darwin-${name}-eval";
      value = pkgs.writeText "darwin-${name}-eval" ''
        hostName=${darwin.config.networking.hostName}
        user=${user}
        hasHomeManager=${if hasHmUser then "true" else "false"}
        homeUser=${homeUser}
        homeDir=${homeDir}
      '';
    }
  ) config.flake.darwinConfigurations;

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
    mkPerSystemCheck {
      inherit system;
      name = "home-smoke";
      value = smokeHome.activationPackage;
    }
  ) homeSystems;
in
{
  config.flake.checks = lib.mkMerge (
    map mergeChecks [
      nixosChecks
      darwinChecks
      homeSmokeChecks
    ]
  );
}
