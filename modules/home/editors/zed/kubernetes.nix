{ inputs, ... }:
{
  aw1cks.modules.home.zed =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.aw1cks.zed.kubernetes;
      pins = builtins.fromJSON (builtins.readFile ./schemas/pins.json);
      catalog = inputs.crds-catalog;
      catalogRevision = catalog.rev or (catalog.narHash or (toString catalog));
      python = pkgs.python3.withPackages (p: [
        p.pyyaml
        p.jsonschema
      ]);
      manifest = pkgs.writeText "zed-kubernetes-schema-inputs.json" (
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
          inherit (cfg) extraCRDs;
        }
      );
      schemas =
        pkgs.runCommand "zed-kubernetes-schemas-${pins.kubernetesVersion}"
          {
            nativeBuildInputs = [ python ];
            preferLocalBuild = true;
          }
          ''
            SCHEMA_BUILDER=${./schemas/build.py} python ${./schemas/test_build.py}
            python ${./schemas/build.py} ${manifest} "$out"
          '';
      # Attribute names cannot carry Nix string context. The xdg source below
      # retains the dependency and keeps the bundle in the Home Manager closure.
      schemaURI = "file://${builtins.unsafeDiscardStringContext (toString schemas)}/bundle.json";
      task = label: text: {
        inherit label;
        command = lib.getExe (
          pkgs.writeShellApplication {
            name = "zed-task";
            inherit text;
          }
        );
        args = [ ];
        save = "none";
        allow_concurrent_runs = false;
        reveal = "always";
        hide = "never";
      };
    in
    {
      options.aw1cks.zed.kubernetes = {
        extraCRDs = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = ''
            Additive local apiextensions.k8s.io/v1 CRD YAML/JSON files (multi-document
            files and Lists supported). Every served version is compiled into the
            editor and kubeconform schema bundle. These override bundled public
            schemas with the same group/version/kind; duplicate downstream GVKs fail.
            Definitions, not resource instances or credentials, belong here. They
            enter the Nix store; remote schema references are rejected.
          '';
        };
        manifestGlobs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Manifest-only YAML globs associated with the shared Kubernetes/CRD bundle.";
        };
        schemaPackage = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "Generated local bundle.json, kubeconform schema tree, and GVK inventory.json.";
        };
      };

      config = {
        aw1cks.zed.kubernetes = {
          schemaPackage = schemas;
          manifestGlobs = [
            "**/k8s/manifests/**/*.yaml"
            "**/k8s/manifests/**/*.yml"
            "**/kubernetes/manifests/**/*.yaml"
            "**/kubernetes/manifests/**/*.yml"
          ];
        };
        xdg.configFile."zed/kubernetes-schemas".source = schemas;
        programs.zed-editor = {
          userSettings.lsp = {
            "yaml-language-server".settings.yaml.schemas.${schemaURI} = cfg.manifestGlobs;
            helm.settings.yamlls.config.schemas.${schemaURI} = "templates/**";
            helm_ls.settings."helm-ls".yamlls.config.schemas.${schemaURI} = "templates/**";
          };
          userTasks = [
            (
              (task "Kubernetes: validate saved manifest (kubeconform)" ''
                exec ${pkgs.kubeconform}/bin/kubeconform \
                  -kubernetes-version ${lib.escapeShellArg pins.kubernetesVersion} \
                  -schema-location '${schemas}/kubeconform/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
                  -strict -summary "$ZED_FILE"
              '')
              // {
                cwd = "$ZED_WORKTREE_ROOT";
              }
            )
            (
              (task "Helm: lint chart (open Chart.yaml first)" ''
                test -f Chart.yaml || { echo "Open a file in the chart root (e.g. Chart.yaml) first." >&2; exit 1; }
                exec ${pkgs.kubernetes-helm}/bin/helm lint --strict --kube-version ${lib.escapeShellArg pins.kubernetesVersion} .
              '')
              // {
                cwd = "$ZED_DIRNAME";
                env.KUBECONFIG = "/dev/null";
              }
            )
            (
              (task "Helm: render chart (open Chart.yaml first)" ''
                test -f Chart.yaml || { echo "Open a file in the chart root (e.g. Chart.yaml) first." >&2; exit 1; }
                exec ${pkgs.kubernetes-helm}/bin/helm template zed-preview . --include-crds --kube-version ${lib.escapeShellArg pins.kubernetesVersion}
              '')
              // {
                cwd = "$ZED_DIRNAME";
                env.KUBECONFIG = "/dev/null";
              }
            )
          ];
        };
      };
    };
}
