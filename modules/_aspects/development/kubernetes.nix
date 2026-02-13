# Kubernetes tools — migrated from nix-old/modules/kubernetes.nix
{ dl, ... }:
{
  dl.dev-kubernetes.homeManager =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        argocd
        cilium-cli
        helm-docs
        helmfile
        hubble
        k9s
        kind
        cloud-provider-kind
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
        kubecolor
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
      ];
    };
}
