{
  # Generate a module for both NixOS and darwin from a single config
  mkSystemModule = mod: {
    nixos = mod;
    darwin = mod;
  };

  # Generate modules for all three classes from a single config
  mkPolyModule = mod: {
    nixos = mod;
    darwin = mod;
    home = mod;
  };

  hostFactsFor =
    {
      facts,
      target,
      name,
    }:
    if builtins.hasAttr name facts then
      facts.${name}
    else
      throw "configurations.${target}.${name}: missing entry in hosts/facts.nix.";

  roleModulesFor =
    { mappings, hostFacts }:
    mappings.base
    ++ builtins.concatLists (map (role: mappings.roles.${role} or [ ]) (hostFacts.roles or [ ]));

  targetAssertions =
    {
      name,
      target,
      system,
      hostFacts,
      extra ? [ ],
    }:
    [
      {
        assertion = hostFacts.system == system;
        message = "configurations.${target}.${name}: facts system ${hostFacts.system} does not match declared system ${system}.";
      }
      {
        assertion = hostFacts.kind == target;
        message = "configurations.${target}.${name}: facts kind must be ${target}, got ${hostFacts.kind}.";
      }
    ]
    ++ extra;

  mkAssertionModule = assertions: { inherit assertions; };

  constructorArgsFor =
    {
      hostFacts,
      target,
    }:
    if target == "home-manager" then
      {
        extraSpecialArgs = { inherit hostFacts; };
      }
    else
      {
        specialArgs = { inherit hostFacts; };
      };

  baseModulesFor =
    {
      inputs,
      config,
      target,
    }:
    {
      nixos = [ inputs.agenix.nixosModules.default ];
      darwin = [
        inputs.agenix.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        config.flake.modules.shared.nixpkgs
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];
      home = [
        inputs.agenix.homeManagerModules.default
        inputs.stylix.homeModules.stylix
      ];
      homeEmbedded = [ inputs.stylix.homeModules.stylix ];
    }
    .${target};

  mkHomeUserModule =
    {
      resolvedUser,
      resolvedHomeDirectory,
      imports ? [ ],
    }:
    {
      imports = imports;
      home.username = resolvedUser;
      home.homeDirectory = resolvedHomeDirectory;
    };

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
}
