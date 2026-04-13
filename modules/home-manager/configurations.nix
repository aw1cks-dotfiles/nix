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
        hostFacts = xlib.hostFactsFor {
          inherit facts name;
          target = "home";
        };
        identity = xlib.selectedIdentityFor {
          inherit config hostFacts;
        };
        resolvedUser = hostFacts.user or identity.username;
        resolvedHomeDirectory = xlib.resolvedHomeDirectoryFor {
          inherit hostFacts identity system;
          target = "home-manager";
        };
      in
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
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
              inherit name system hostFacts;
              target = "home-manager";
              extra = [
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
                  message = "configurations.home.${name}: resolved identity username is required for standalone Home Manager hosts.";
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
          (lib.mkIf (lib.hasSuffix "-linux" system) {
            targets.genericLinux.enable = true;
          })
          (lib.mkIf nvidia.enable (nvidiaModuleFor meta))
        ];
      }
    ) cfg;

    aw1cks.homeNvidiaConfigurations = builtins.listToAttrs nvidiaEntries;
  };
}
