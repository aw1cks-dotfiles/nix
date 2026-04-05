# Shell CLI tools — migrated from nix-old/modules/shell.nix
{ ... }:
{
  flake.modules.home.cli-tools =
    { pkgs, lib, ... }:
    {
      home.packages =
        with pkgs;
        [
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
          tree
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
          grpcurl
          inetutils
          ipcalc
          kafkactl
          kcat
          mitmproxy
          mtr
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
          lazyjournal
          terraform
          terraform-docs
          vault
        ]
        # Linux-only tools are omitted on nix-darwin hosts.
        ++ lib.optionals pkgs.stdenv.isLinux [
          grpc_cli
          inotify-info
          inotify-tools
          netcat-openbsd
          openldap
        ];

      programs.bat = {
        enable = true;
        extraPackages = with pkgs; [
          bat-extras.core
        ];
        config = {
          nonprintable-notation = "caret";
          paging = "auto";
          style = "changes,numbers";
          theme = "Catppuccin Mocha";
        };
      };

      # TODO: set this up for cleaning up apps not respecting XDG
      # programs.boxxy.enable = true;
    };
}
