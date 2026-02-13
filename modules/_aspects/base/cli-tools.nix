# Shell CLI tools — migrated from nix-old/modules/shell.nix
{ dl, ... }:
{
  dl.base-cli-tools.homeManager =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # shell utils
        bat
        bat-extras.core
        dust
        direnv
        fd
        fzf
        moreutils
        ncdu
        opensshWithKerberos
        powershell
        pwgen
        ripgrep
        tmux
        uutils-coreutils-noprefix
        uutils-diffutils
        uutils-findutils
        zsh
        zstd

        # theming
        starship
        vivid

        # networking
        cfssl
        dnsutils
        grpc_cli
        grpcurl
        inetutils
        ipcalc
        kafkactl
        kcat
        mitmproxy
        mtr
        netcat-openbsd
        net-snmp
        nmap
        rclone
        s5cmd
        step-cli

        # editor & deps
        neovim
        tree-sitter

        # db
        clickhouse
        etcd
        pgcli
        postgresql
        sqlcmd
        sqlite

        # nix
        nixfmt
        nix-direnv
        statix

        # linters
        shellcheck
        shellharden
        yamlfmt
        yamllint

        # data processing
        jq
        yq-go

        # diagramming
        d2
        graphviz

        # misc
        coder
        pandoc
        fswatch
        inotify-info
        inotify-tools
        lazyjournal
        openldap
        terraform
        terraform-docs
        vault
      ];
    };
}
