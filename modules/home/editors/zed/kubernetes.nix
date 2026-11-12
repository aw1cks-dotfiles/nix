{ config, ... }:
let
  yamlSchemasModule = config.aw1cks.modules.home.yaml-schemas;
in
{
  aw1cks.modules.home.zed =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.aw1cks.yaml.kubernetes;
      schemas = cfg.schemaPackage;
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
      imports = [ yamlSchemasModule ];

      config = {
        programs.zed-editor = {
          userSettings.lsp = {
            "yaml-language-server".settings.yaml.schemas = config.aw1cks.yaml.schemaAssociations;
          };
          userTasks = [
            (
              (task "Kubernetes: validate saved manifest (kubeconform)" ''
                exec ${pkgs.kubeconform}/bin/kubeconform \
                  -kubernetes-version ${lib.escapeShellArg cfg.kubernetesVersion} \
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
                exec ${pkgs.kubernetes-helm}/bin/helm lint --strict --kube-version ${lib.escapeShellArg cfg.kubernetesVersion} .
              '')
              // {
                cwd = "$ZED_DIRNAME";
                env.KUBECONFIG = "/dev/null";
              }
            )
            (
              (task "Helm: render chart (open Chart.yaml first)" ''
                test -f Chart.yaml || { echo "Open a file in the chart root (e.g. Chart.yaml) first." >&2; exit 1; }
                exec ${pkgs.kubernetes-helm}/bin/helm template zed-preview . --include-crds --kube-version ${lib.escapeShellArg cfg.kubernetesVersion}
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
