{
  lib,
  config,
  inputs,
  ...
}:
let
  facts = config.flake.hostFacts;
  darwinRoleMappings = config.flake.roles.darwin;
  homeRoleMappings = config.flake.roles.home;

  hostFactsFor =
    name:
    if builtins.hasAttr name facts then
      facts.${name}
    else
      throw "configurations.darwin.${name}: missing entry in hosts/facts.nix.";

  roleModulesFor =
    mappings: hostFacts:
    mappings.base ++ lib.concatMap (role: mappings.roles.${role} or [ ]) (hostFacts.roles or [ ]);
in
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
          };
          system = lib.mkOption {
            type = lib.types.str;
            description = "System string, e.g. x86_64-darwin or aarch64-darwin.";
          };
          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "User name for home-manager configuration.";
          };
          homeDirectory = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Home directory for the primary darwin user and embedded Home Manager config.";
          };
          home = lib.mkOption {
            type = lib.types.nullOr lib.types.deferredModule;
            default = null;
            description = "Optional home-manager configuration to embed via the HM darwin module.";
          };
        };
      }
    );
    default = { };
  };

  config.flake.darwinConfigurations = lib.mapAttrs (
    name:
    {
      module,
      system,
      user ? null,
      homeDirectory ? null,
      home ? null,
    }:
    let
      hostFacts = hostFactsFor name;
      resolvedUser = if user != null then user else hostFacts.user or null;
      resolvedHomeDirectory =
        if homeDirectory != null then homeDirectory else hostFacts.homeDirectory or null;
    in
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit hostFacts;
      };
      modules = [
        ({
          assertions = [
            {
              assertion = hostFacts.system == system;
              message = "configurations.darwin.${name}: facts system ${hostFacts.system} does not match declared system ${system}.";
            }
            {
              assertion = hostFacts.kind == "darwin";
              message = "configurations.darwin.${name}: facts kind must be darwin, got ${hostFacts.kind}.";
            }
            {
              assertion = resolvedUser != null;
              message = "configurations.darwin.${name}: facts user is required for darwin hosts.";
            }
            {
              assertion = resolvedHomeDirectory != null;
              message = "configurations.darwin.${name}: facts homeDirectory is required for darwin hosts.";
            }
          ];
        })
      ]
      ++ roleModulesFor darwinRoleMappings hostFacts
      ++ [
        module
        inputs.agenix.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        config.flake.modules.shared.nixpkgs
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
        {
          nixpkgs.hostPlatform = lib.mkDefault hostFacts.system;
        }
        (lib.mkIf (resolvedUser != null) {
          system.primaryUser = lib.mkDefault resolvedUser;
          nix.settings.trusted-users = lib.mkAfter [ resolvedUser ];
        })
        (lib.mkIf (resolvedUser != null && resolvedHomeDirectory != null) {
          users.users.${resolvedUser}.home = lib.mkDefault resolvedHomeDirectory;
        })
        (lib.mkIf (home != null && resolvedUser != null && resolvedHomeDirectory != null) {
          home-manager.users.${resolvedUser} = {
            imports = roleModulesFor homeRoleMappings hostFacts ++ [
              inputs.stylix.homeModules.stylix
              home
            ];
            home.username = lib.mkDefault resolvedUser;
            home.homeDirectory = lib.mkDefault resolvedHomeDirectory;
          };
        })
      ];
    }
  ) config.configurations.darwin;
}
