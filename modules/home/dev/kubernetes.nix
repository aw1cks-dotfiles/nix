# Kubernetes tools — migrated from nix-old/modules/kubernetes.nix
{ lib, ... }:
{
  aw1cks.modules.home.kubernetes =
    { pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          argocd
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
              kubernetes-helmPlugins.helm-unittest
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
