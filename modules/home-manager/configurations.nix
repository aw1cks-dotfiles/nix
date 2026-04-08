{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.configurations.home;
  facts = config.flake.hostFacts;
  roleMappings = config.flake.roles.home;

  hostFactsFor =
    name:
    if builtins.hasAttr name facts then
      facts.${name}
    else
      throw "configurations.home.${name}: missing entry in hosts/facts.nix.";

  extractShortHost =
    name:
    let
      match = builtins.match "^[^@]+@([^.]+)(\\..*)?$" name;
    in
    if match == null then
      throw ''
        configurations.home attribute names must follow user@host or user@host.domain
        when nvidia.enable = true; got: ${name}
      ''
    else
      builtins.elemAt match 0;

  nvidiaArchForSystem =
    system:
    if system == "x86_64-linux" then
      "x86_64"
    else if system == "aarch64-linux" then
      "aarch64"
    else
      throw "Unsupported NVIDIA Linux system for home configuration: ${system}";

  homeMetadata = lib.mapAttrs (
    name:
    { system, nvidia, ... }:
    let
      shortHost = extractShortHost name;
    in
    {
      inherit name system shortHost;
      nvidia = {
        enable = nvidia.enable;
        pinFile = if nvidia.enable then nvidia.pinFile else null;
        arch = if nvidia.enable then nvidiaArchForSystem system else null;
      };
    }
  ) cfg;

  nvidiaModuleFor =
    meta:
    let
      pins = builtins.fromJSON (builtins.readFile meta.nvidia.pinFile);
    in
    {
      targets.genericLinux = {
        enable = true;
        gpu.nvidia = {
          enable = true;
          version = pins.version;
          sha256 = pins.sha256;
        };
      };
    };

  roleModulesFor =
    hostFacts:
    roleMappings.base
    ++ lib.concatMap (role: roleMappings.roles.${role} or [ ]) (hostFacts.roles or [ ]);

  nvidiaEntries = lib.mapAttrsToList (
    _: meta:
    lib.nameValuePair meta.shortHost {
      attr = meta.name;
      system = meta.system;
      arch = meta.nvidia.arch;
      pinFile = meta.nvidia.pinFile;
    }
  ) (lib.filterAttrs (_: meta: meta.nvidia.enable) homeMetadata);

  duplicateShortHosts =
    let
      shortHosts = lib.mapAttrsToList (_: meta: meta.shortHost) homeMetadata;
    in
    lib.unique (lib.filter (host: lib.length (lib.filter (x: x == host) shortHosts) > 1) shortHosts);
in
{
  options.configurations.home = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption {
            type = lib.types.deferredModule;
          };
          system = lib.mkOption {
            type = lib.types.str;
            description = "System string, e.g. x86_64-linux or aarch64-darwin.";
          };

          nvidia = {
            enable = lib.mkEnableOption "NVIDIA pin metadata for updater tooling";

            pinFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = ''
                Path to the host-local Nix file containing NVIDIA driver pins.
                Required when nvidia.enable = true.
              '';
            };
          };
        };
      }
    );
    default = { };
  };

  config = {
    flake.homeConfigurations = lib.mapAttrs (
      name:
      {
        module,
        system,
        nvidia,
        ...
      }:
      let
        meta = homeMetadata.${name};
        hostFacts = hostFactsFor name;
        resolvedUser = hostFacts.user or null;
        resolvedHomeDirectory = hostFacts.homeDirectory or null;
      in
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit hostFacts;
        };
        modules = [
          {
            assertions = [
              {
                assertion = hostFacts.system == system;
                message = "configurations.home.${name}: facts system ${hostFacts.system} does not match declared system ${system}.";
              }
              {
                assertion = hostFacts.kind == "home-manager";
                message = "configurations.home.${name}: facts kind must be home-manager, got ${hostFacts.kind}.";
              }
              {
                assertion = duplicateShortHosts == [ ];
                message = "Duplicate inferred home short hostnames: ${lib.concatStringsSep ", " duplicateShortHosts}";
              }
              {
                assertion = (!nvidia.enable) || lib.hasSuffix "-linux" system;
                message = "configurations.home.${name}.nvidia.enable requires a Linux system.";
              }
              {
                assertion = (!nvidia.enable) || meta.nvidia.pinFile != null;
                message = "configurations.home.${name}.nvidia.pinFile is required when nvidia.enable = true.";
              }
              {
                assertion = (!nvidia.enable) || builtins.pathExists meta.nvidia.pinFile;
                message = "configurations.home.${name}.nvidia.pinFile does not exist: ${meta.nvidia.pinFile}";
              }
              {
                assertion = resolvedUser != null;
                message = "configurations.home.${name}: facts user is required for standalone Home Manager hosts.";
              }
              {
                assertion = resolvedHomeDirectory != null;
                message = "configurations.home.${name}: facts homeDirectory is required for standalone Home Manager hosts.";
              }
              {
                assertion =
                  (!nvidia.enable)
                  || (
                    let
                      pins = builtins.fromJSON (builtins.readFile meta.nvidia.pinFile);
                    in
                    builtins.isAttrs pins && builtins.hasAttr "version" pins && builtins.hasAttr "sha256" pins
                  );
                message = "configurations.home.${name}.nvidia.pinFile must be a JSON object with version and sha256 keys: ${meta.nvidia.pinFile}";
              }
            ];
          }
        ]
        ++ roleModulesFor hostFacts
        ++ [
          {
            home.username = lib.mkDefault resolvedUser;
            home.homeDirectory = lib.mkDefault resolvedHomeDirectory;
          }
          module
          (lib.mkIf nvidia.enable (nvidiaModuleFor meta))
          inputs.agenix.homeManagerModules.default
          inputs.stylix.homeModules.stylix
        ];
      }
    ) cfg;

    flake.homeNvidiaConfigurations = builtins.listToAttrs nvidiaEntries;
  };
}
