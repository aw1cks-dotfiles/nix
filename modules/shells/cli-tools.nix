# Shell CLI tools — migrated from nix-old/modules/shell.nix
{ ... }:
{
  flake.modules.home.cli-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # shell utils
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

      programs.bat = {
        enable = true;
        extraPackages = with pkgs; [
          bat-extras.core
        ];
        config = {
          theme = "Catppuccin Mocha";
        };
      };
      ### this uses a base16-based theme, which does not seem to work well.
      # stylix.targets = {
      #   bat.enable = true;
      # };
    };
}
