rec {
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

  validateRolesFor =
    {
      allMappings,
      hostFacts,
      target,
      name,
    }:
    let
      knownRoles = builtins.attrNames (
        builtins.foldl' (acc: mapping: acc // mapping.roles) { } (builtins.attrValues allMappings)
      );
      unknownRoles = builtins.filter (role: !(builtins.elem role knownRoles)) (hostFacts.roles or [ ]);
    in
    [
      {
        assertion = unknownRoles == [ ];
        message = "configurations.${target}.${name}: unknown role name(s) in hosts/facts.nix: ${builtins.concatStringsSep ", " unknownRoles}.";
      }
    ];

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

  configuredPkgsFor =
    {
      inputs,
      system,
      enableLix ? true,
    }:
    import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
        nvidia.acceptLicense = true;
      };
      overlays = (if enableLix then [ inputs.lix-module.overlays.default ] else [ ]) ++ [
        (_final: _prev: {
          unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          # containerd 2.2.3+ and nerdctl 2.2.2+ are required by the shared
          # nerdctl module for EROFS snapshotter support. nixpkgs stable lags
          # significantly behind unstable for both; promote from unstable.
          containerd = _final.unstable.containerd;
          nerdctl = _final.unstable.nerdctl;
          # buildkit 0.25+ is required for nerdctl build with containerd worker.
          buildkit = _final.unstable.buildkit;
        })
        inputs.llm-agents.overlays.default
      ];
    };

  baseModulesFor =
    {
      inputs,
      config,
      target,
    }:
    {
      nixos = [
        inputs.disko.nixosModules.disko
        inputs.agenix.nixosModules.default
        config.aw1cks.modules.shared.nixpkgs
      ];
      nixosEmbedded = [ inputs.stylix.homeModules.stylix ];
      darwin = [
        inputs.agenix.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        config.aw1cks.modules.shared.nixpkgs
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

  defaultHomeDirectoryFor =
    {
      system ? null,
      target ? null,
      username,
    }:
    if target == "darwin" || (system != null && builtins.match ".*-darwin" system != null) then
      "/Users/${username}"
    else
      "/home/${username}";

  selectedIdentityFor =
    {
      config,
      hostFacts,
    }:
    let
      identityName = hostFacts.identity or config.aw1cks.identity.default;
    in
    if builtins.hasAttr identityName config.aw1cks.identities then
      config.aw1cks.identities.${identityName}
    else
      throw "aw1cks identity '${identityName}' is not defined in aw1cks.identities.";

  resolvedHomeDirectoryFor =
    {
      hostFacts,
      identity,
      system ? null,
      target ? null,
    }:
    if hostFacts ? homeDirectory then
      hostFacts.homeDirectory
    else if identity.homeDirectory != null then
      identity.homeDirectory
    else
      defaultHomeDirectoryFor {
        inherit system target;
        username = identity.username;
      };
}
