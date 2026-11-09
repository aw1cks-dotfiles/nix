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
          ktlint
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
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          grpc_cli
          inotify-info
          inotify-tools
          netcat-openbsd
          openldap
        ];

      programs.bat = {
        enable = true;
        themes.oxocarbon-dark.src = ./files/bat/oxocarbon-dark.tmTheme;
        syntaxes = {
          Go.src = ./files/bat/syntaxes/Go.sublime-syntax;
          JSON.src = ./files/bat/syntaxes/JSON.sublime-syntax;
          Python.src = ./files/bat/syntaxes/Python.sublime-syntax;
          Rust.src = ./files/bat/syntaxes/Rust.sublime-syntax;
        };
        extraPackages = with pkgs; [
          bat-extras.core
        ];
        config = {
          nonprintable-notation = "caret";
          paging = "auto";
          style = "changes,numbers";
          theme = "oxocarbon-dark";
        };
      };

      # TODO: set this up for cleaning up apps not respecting XDG
      # programs.boxxy.enable = true;
    };
}
