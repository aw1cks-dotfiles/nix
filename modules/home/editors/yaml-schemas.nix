{ inputs, ... }:
{
  aw1cks.modules.home.yaml-schemas =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.aw1cks.yaml;
      pins = builtins.fromJSON (builtins.readFile ./_yaml-schemas/pins.json);
      catalog = inputs.crds-catalog;
      catalogRevision = catalog.rev or (catalog.narHash or (toString catalog));
      python = pkgs.python3.withPackages (p: [
        p.pyyaml
        p.jsonschema
      ]);
      manifest = pkgs.writeText "kubernetes-schema-inputs.json" (
        builtins.toJSON {
          inherit (pins) kubernetesVersion;
          inherit catalogRevision;
          definitions = pkgs.fetchurl pins.definitions;
          schemas = map (
            entry:
            entry
            // {
              path = "${catalog}/${entry.path}";
              source = "crds-catalog:${catalogRevision}/${entry.path}";
            }
          ) pins.schemas;
          inherit (cfg.kubernetes) extraCRDs;
        }
      );
      schemas =
        pkgs.runCommand "kubernetes-schemas-${pins.kubernetesVersion}"
          {
            nativeBuildInputs = [ python ];
            preferLocalBuild = true;
          }
          ''
            SCHEMA_BUILDER=${./_yaml-schemas/build.py} python ${./_yaml-schemas/test_build.py}
            python ${./_yaml-schemas/build.py} ${manifest} "$out"
          '';
      customSchemas = lib.imap0 (
        index: entry:
        let
          source = lib.removePrefix "file://" "${entry.schema}";
          local = lib.hasPrefix "/" source;
        in
        {
          inherit index source local;
          uri = if local then "file://${source}" else "${entry.schema}";
          inherit (entry) fileMatch;
        }
      ) cfg.extraSchemas;
      associations = [
        {
          uri = "file://${schemas}/bundle.json";
          fileMatch = cfg.kubernetes.manifestGlobs;
        }
      ]
      ++ customSchemas;
    in
    {
      key = "aw1cks-yaml-schemas";

      options.aw1cks.yaml = {
        extraSchemas = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                schema = lib.mkOption {
                  type = lib.types.either lib.types.path lib.types.str;
                  description = "JSON schema path, store-package file, or explicit schema URI.";
                };
                fileMatch = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "YAML filename globs associated with this schema.";
                };
              };
            }
          );
          default = [ ];
          description = "Additive YAML schema associations shared by Neovim and Zed. Local schemas enter the Nix store; URLs may be fetched by the language server.";
        };
        schemaAssociations = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          readOnly = true;
          description = "Resolved schema URI to filename-glob mapping for editor consumers.";
        };
        kubernetes = {
          extraCRDs = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            default = [ ];
            description = ''
              Additive local apiextensions.k8s.io/v1 CRD YAML/JSON definitions,
              including multi-document files and Lists. Served versions override
              bundled matching GVKs; duplicate extra GVKs fail. Definitions enter
              the Nix store and must not contain secrets or remote references.
            '';
          };
          manifestGlobs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additive manifest-only YAML globs; use mkForce to replace the defaults.";
          };
          schemaPackage = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
            description = "Pinned strict bundle, detected.json fallback, GVK inventory, and kubeconform schemas.";
          };
          kubernetesVersion = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            description = "Kubernetes version used by the pinned schema bundle.";
          };
        };
      };

      config = {
        aw1cks.yaml = {
          kubernetes = {
            schemaPackage = schemas;
            inherit (pins) kubernetesVersion;
            manifestGlobs = [
              "**/k8s/manifests/**/*.yaml"
              "**/k8s/manifests/**/*.yml"
              "**/kubernetes/manifests/**/*.yaml"
              "**/kubernetes/manifests/**/*.yml"
            ];
          };
          # Attribute names cannot retain string context; data links below keep
          # generated and custom local schemas in the Home Manager closure.
          schemaAssociations = lib.foldl' (
            result: entry:
            let
              uri = builtins.unsafeDiscardStringContext entry.uri;
            in
            result // { ${uri} = lib.unique ((result.${uri} or [ ]) ++ entry.fileMatch); }
          ) { } associations;
        };
        xdg.dataFile = lib.listToAttrs (
          [ (lib.nameValuePair "yaml-schemas/kubernetes" { source = schemas; }) ]
          ++ map (
            entry:
            lib.nameValuePair "yaml-schemas/custom-${toString entry.index}.json" {
              source = entry.source;
            }
          ) (builtins.filter (entry: entry.local) customSchemas)
        );
      };
    };
}
