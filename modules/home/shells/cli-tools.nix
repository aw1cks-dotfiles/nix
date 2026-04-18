# Shell CLI tools — migrated from nix-old/modules/shell.nix
{ ... }:
{
  aw1cks.modules.home.cli-tools =
    { pkgs, lib, ... }:
    {
      home.packages =
        with pkgs;
        [
          # shell utils
          dust
          glow
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
          zstd

          # networking
          cfssl
          curlFull
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
          rsync
          s5cmd
          sshfs
          step-cli

          # db
          clickhouse
          etcd
          pgcli
          postgresql
          sqlcmd
          sqlite

          # nix
          nixfmt
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
          tectonic
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
