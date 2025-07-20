{ config, lib, pkgs, nixgl, ... }:
{
  # Allow unfree packages
  # NOTE: this is only for home-manager's nixpkgs instance.
  # nixGL will also need to pull in non-free packages (nvidia);
  # see the ~/.config/nixpkgs/config.nix file in the README
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  # Make sure home-manager manages itself so it doesn't get GC'd
  programs.home-manager.enable = true;

  # Configure NixGL for running apps that require OpenGL/Vulkan
  nixGL.packages = nixgl.packages;
  nixGL.defaultWrapper = "nvidia";
  nixGL.vulkan.enable = true;

  home.stateVersion = "25.05";

  home.username = "alex";
  home.homeDirectory = "/home/alex";

  home.packages = with pkgs; [
    argocd
    cilium-cli
    helm-docs
    helmfile
    hubble
    k9s
    kind
    kube-capacity
    kubectl
    kubectl-df-pv
    kubectl-graph
    kubectl-klock
    kubectl-ktop
    kubectl-neat
    kubectl-node-shell
    kubectl-tree
    kubecolor
    kubectx
    kubelogin-oidc
    kubernetes-helm
    kustomize
    stern

    bat
    cfssl
    claude-code
    clickhouse-cli
    cmake
    coder
    crane
    d2
    delta
    delve
    difftastic
    dive
    dotnet-runtime
    dotnet-sdk
    etcd
    fd
    fzf
    gdlv
    gh
    gh-f
    gitFull
    git-doc
    gitkraken
    go
    graphviz
    grpcurl
    inetutils
    jq
    lazyjournal
    maven
    (config.lib.nixGL.wrap meld)
    mitmproxy
    moreutils
    mtr
    netcat-openbsd
    net-snmp
    neovim
    nmap
    nodejs_24
    openldap
    pandoc
    pgcli
    podman
    powershell
    pwgen
    rclone
    ripgrep
    rustup
    s5cmd
    shellcheck
    shellharden
    skopeo
    sqlcmd
    sqlx-cli
    starship
    step-cli
    terraform
    tig
    tree-sitter
    tmux
    typescript
    uutils-findutils
    uutils-diffutils
    uutils-coreutils-noprefix
    uv
    vault
    (config.lib.nixGL.wrap wezterm)
    (config.lib.nixGL.wrap wireshark)
    yamllint
    yarn-berry
    yq
    zstd
  ];
}
