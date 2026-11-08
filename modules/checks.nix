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

  nixosChecks = lib.mapAttrsToList (
    name: nixos:
    let
      system = nixos.config.nixpkgs.hostPlatform.system;
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      users = nixos.config.users.users or { };
      primaryUsers = builtins.attrNames (lib.filterAttrs (_: user: user.isNormalUser or false) users);
      shellPolicy = lib.attrByPath [ "aw1cks" "user" "shellPolicy" ] "" nixos.config;
      sshPorts = builtins.concatStringsSep "," (
        map toString (nixos.config.services.openssh.ports or [ ])
      );
    in
    mkPerSystemCheck {
      inherit system;
      name = "nixos-${name}-eval";
      value = pkgs.writeText "nixos-${name}-eval" ''
        hostName=${nixos.config.networking.hostName}
        system=${system}
        primaryUsers=${builtins.concatStringsSep "," primaryUsers}
        shellPolicy=${shellPolicy}
        mutableUsers=${if nixos.config.users.mutableUsers then "true" else "false"}
        opensshEnabled=${if nixos.config.services.openssh.enable then "true" else "false"}
        opensshPorts=${sshPorts}
      '';
    }
  ) config.flake.nixosConfigurations;

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

  # Resolve target systems without forcing foreign hosts' final derivations.
  hostDerivations =
    lib.mapAttrsToList (name: nixos: {
      inherit name;
      kind = "nixos";
      system = nixos.config.nixpkgs.hostPlatform.system;
      drvPath = nixos.config.system.build.toplevel.drvPath;
    }) config.flake.nixosConfigurations
    ++ lib.mapAttrsToList (name: darwin: {
      inherit name;
      kind = "darwin";
      system = darwin.config.nixpkgs.hostPlatform.system;
      drvPath = darwin.system.drvPath;
    }) config.flake.darwinConfigurations
    ++ lib.mapAttrsToList (name: home: {
      inherit name;
      kind = "home";
      system = home.pkgs.stdenv.hostPlatform.system;
      drvPath = home.activationPackage.drvPath;
    }) config.flake.homeConfigurations;

  hostDerivationChecks = map (
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      nativeHosts = builtins.filter (host: host.system == system) hostDerivations;
    in
    mkPerSystemCheck {
      inherit system;
      name = "host-derivations";
      # Force the native derivations, then discard their contexts so the manifest
      # does not build or retain host closures.
      value = pkgs.writeText "host-derivations.json" (
        builtins.unsafeDiscardStringContext (builtins.toJSON nativeHosts)
      );
    }
  ) config.systems;

  # Group skill checks under each system before the existing shallow merge.
  skillsChecks = map (
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      skills = import ./home/dev/_skills.nix { inherit inputs lib pkgs; };
    in
    {
      ${system} = {
        agent-skills = import ./home/dev/_skills-checks.nix {
          inherit inputs lib pkgs;
          aiModule = config.aw1cks.modules.home.ai;
        };
        agent-omp-skills = import ./home/dev/_omp-skills-checks.nix {
          inherit inputs lib pkgs;
          aiModule = config.aw1cks.modules.home.ai;
        };
        agent-omp-lsp = import ./home/dev/_omp-lsp-checks.nix {
          inherit inputs lib pkgs;
          aiModule = config.aw1cks.modules.home.ai;
        };
        agent-skill-input-gate =
          pkgs.runCommand "agent-skill-input-gate"
            {
              nativeBuildInputs = [ pkgs.python3Packages.pytest ];
            }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              pytest -p no:cacheprovider ${../.github}/test_skill_input_gate.py
              touch "$out"
            '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        agent-skills-patches = import ./home/dev/_skills-patch-checks.nix {
          inherit pkgs;
          skillsSource = skills.build {
            select = [
              "lowlevel/cpp-coroutines"
              "lowlevel/io-uring"
              "lowlevel/kernel-debugging"
            ];
          };
        };
      };
    }
  ) config.systems;
in
{
  config.flake.checks = lib.mkMerge (
    map mergeChecks [
      nixosChecks
      darwinChecks
      homeSmokeChecks
      hostDerivationChecks
      skillsChecks
    ]
  );
}
