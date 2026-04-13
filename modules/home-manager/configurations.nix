{
  lib,
  config,
  inputs,
  ...
}:
let
  xlib = import ../_lib/default.nix;
  cfg = config.configurations.home;
  facts = config.aw1cks.hostFacts;
  roleMappings = config.aw1cks.roles.home;

  parseHomeConfigName =
    name:
    let
      match = builtins.match "^([^@]+)@([^.]+)(\\..*)?$" name;
    in
    if match == null then
      throw ''
        configurations.home attribute names must follow user@host or user@host.domain; got: ${name}
      ''
    else
      {
        user = builtins.elemAt match 0;
        shortHost = builtins.elemAt match 1;
      };

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
      parsedName = parseHomeConfigName name;
      hostFacts = xlib.hostFactsFor {
        inherit facts name;
        target = "home";
      };
      resolvedSystem = if system != null then system else hostFacts.system;
    in
    {
      inherit name;
      inherit (parsedName) user shortHost;
      system = resolvedSystem;
      nvidia = {
        enable = nvidia.enable;
        pinFile = if nvidia.enable then nvidia.pinFile else null;
        arch = if nvidia.enable then nvidiaArchForSystem resolvedSystem else null;
      };
    }
  ) cfg;

  nvidiaModuleFor =
    meta:
    let
      pins = builtins.fromJSON (builtins.readFile meta.nvidia.pinFile);
    in
    {
      targets.genericLinux.gpu.nvidia = {
        enable = true;
        version = pins.version;
        sha256 = pins.sha256;
      };
    };

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
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional system string, e.g. x86_64-linux or aarch64-darwin. Defaults from host facts when omitted.";
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
        system ? null,
        nvidia,
        ...
      }:
      let
        meta = homeMetadata.${name};
        hostFacts = xlib.hostFactsFor {
          inherit facts name;
          target = "home";
        };
        identity = xlib.selectedIdentityFor {
          inherit config hostFacts;
        };
        resolvedSystem = if system != null then system else hostFacts.system;
        resolvedUser = hostFacts.user or identity.username;
        resolvedHomeDirectory = xlib.resolvedHomeDirectoryFor {
          inherit hostFacts identity;
          system = resolvedSystem;
          target = "home-manager";
        };
      in
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${resolvedSystem};
        inherit
          (xlib.constructorArgsFor {
            inherit hostFacts;
            target = "home-manager";
          })
          extraSpecialArgs
          ;
        modules = [
          (xlib.mkAssertionModule (
            xlib.targetAssertions {
              inherit name hostFacts;
              system = resolvedSystem;
              target = "home-manager";
              extra =
                xlib.validateRolesFor {
                  allMappings = config.aw1cks.roles;
                  inherit hostFacts name;
                  target = "home-manager";
                }
                ++ [
                  {
                    assertion = duplicateShortHosts == [ ];
                    message = "Duplicate inferred home short hostnames: ${lib.concatStringsSep ", " duplicateShortHosts}";
                  }
                  {
                    assertion = (!nvidia.enable) || lib.hasSuffix "-linux" resolvedSystem;
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
                    message = "configurations.home.${name}: resolved identity username is required for standalone Home Manager hosts.";
                  }
                  {
                    assertion = resolvedUser == null || meta.user == resolvedUser;
                    message = "configurations.home.${name}: attribute-name user '${meta.user}' must match resolved user '${resolvedUser}'.";
                  }
                  {
                    assertion = resolvedHomeDirectory != null;
                    message = "configurations.home.${name}: resolved identity homeDirectory is required for standalone Home Manager hosts.";
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
          ))
        ]
        ++ xlib.roleModulesFor {
          mappings = roleMappings;
          inherit hostFacts;
        }
        ++ xlib.baseModulesFor {
          inherit inputs config;
          target = "home";
        }
        ++ [
          (xlib.mkHomeUserModule {
            inherit resolvedUser resolvedHomeDirectory;
          })
          module
          # Enable genericLinux for all standalone Linux Home Manager hosts.
          # This is the home-manager-supported mechanism for non-NixOS PATH,
          # XDG dirs, and shell integration. The nvidia GPU sub-option is
          # layered on top only when a pin file is provided.
          (lib.mkIf (lib.hasSuffix "-linux" resolvedSystem) {
            targets.genericLinux.enable = true;
          })
          (lib.mkIf nvidia.enable (nvidiaModuleFor meta))
        ];
      }
    ) cfg;

    aw1cks.homeNvidiaConfigurations = builtins.listToAttrs nvidiaEntries;
  };
}
