# Kubernetes tools — migrated from nix-old/modules/kubernetes.nix
{ lib, ... }:
{
  aw1cks.modules.home.kubernetes =
    { pkgs, ... }:
    let
      helm-unittest = pkgs.kubernetes-helmPlugins.helm-unittest.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          if grep -q '$HELM_PLUGIN_DIR/untt-linux-amd64' "$out/helm-unittest/plugin.yaml"; then
            substituteInPlace "$out/helm-unittest/plugin.yaml" \
              --replace-fail '$HELM_PLUGIN_DIR/untt-linux-amd64' '$HELM_PLUGIN_DIR/untt' \
              --replace-fail '$HELM_PLUGIN_DIR/untt-linux-arm64' '$HELM_PLUGIN_DIR/untt' \
              --replace-fail '$HELM_PLUGIN_DIR/untt-linux-ppc64le' '$HELM_PLUGIN_DIR/untt' \
              --replace-fail '$HELM_PLUGIN_DIR/untt-linux-s390x' '$HELM_PLUGIN_DIR/untt' \
              --replace-fail '$HELM_PLUGIN_DIR/untt-macos-amd64' '$HELM_PLUGIN_DIR/untt' \
              --replace-fail '$HELM_PLUGIN_DIR/untt-macos-arm64' '$HELM_PLUGIN_DIR/untt'
          fi
        '';
      });
    in
    {
      home.packages =
        with pkgs;
        [
          argo-expr
          argo-rollouts
          argo-workflows
          argocd
          argonaut
          cilium-cli
          helm-docs
          helmfile
          hubble
          kube-capacity
          kubebuilder
          kubectl
          kubectl-cnpg
          kubectl-df-pv
          kubectl-graph
          kubectl-klock
          kubectl-ktop
          kubectl-neat
          kubectl-node-shell
          kubectl-tree
          kubectl-view-allocations
          kubeconform
          kubectx
          kubelogin-oidc
          (wrapHelm kubernetes-helm {
            plugins = [
              kubernetes-helmPlugins.helm-diff
              kubernetes-helmPlugins.helm-secrets
              helm-unittest
            ];
          })
          kustomize
          stern
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          kind
          cloud-provider-kind
          minikube
        ];

      programs = {
        k9s.enable = true;
        kubecolor = {
          enable = true;
          settings = {
            objFreshThreshold = "1h";
            preset = "dark";
            paging = "auto";
            pager = "less -RF";
          };
        };
      };
    };
}
