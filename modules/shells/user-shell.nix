{ lib, ... }:
let
  zshInitPrelude = ''
    setopt extended_history
    setopt hist_verify
    setopt inc_append_history
    setopt rmstarsilent
    setopt interactivecomments
    unsetopt completealiases

    bindkey -e
    bindkey '^i' expand-or-complete-prefix
    bindkey '^[[1;5C' forward-word
    bindkey '^[[1;5D' backward-word
    bindkey '^[[H' beginning-of-line
    bindkey '^[[F' end-of-line
    bindkey '^[[Z' end-of-line
    bindkey '\e[Z' reverse-menu-complete
    bindkey '^[[3~' delete-char
    bindkey '\e[A' history-beginning-search-backward
    bindkey '\e[B' history-beginning-search-forward
    bindkey -s '^k' '^ukubectx^M'
    bindkey -s '^[^k' '^ukubectx -u^M'
    bindkey -s '^n' '^ukubens^M'

    zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
    zstyle ':completion:*' menu select
    zstyle ':completion:*:default' list-colors ''${(s.:.)LS_COLORS}
  '';
in
{
  flake.modules.home.zsh =
    { config, pkgs, ... }:
    let
      clipboardHelpers =
        if pkgs.stdenv.isDarwin then
          ''
            function resolve_clipboard_copy_command() {
              REPLY='pbcopy'
            }

            function resolve_clipboard_paste_command() {
              REPLY='pbpaste'
            }
          ''
        else
          ''
            function resolve_clipboard_copy_command() {
              case "''${XDG_SESSION_TYPE:-}" in
                wayland)
                  if command -v wl-copy >/dev/null 2>&1; then
                    REPLY='wl-copy'
                    return 0
                  fi
                  ;;
                x11)
                  if command -v xclip >/dev/null 2>&1; then
                    REPLY='xclip -selection clipboard'
                    return 0
                  fi
                  ;;
              esac

              if command -v wl-copy >/dev/null 2>&1; then
                REPLY='wl-copy'
              elif command -v xclip >/dev/null 2>&1; then
                REPLY='xclip -selection clipboard'
              else
                printf 'No clipboard copy command available\n' >&2
                return 1
              fi
            }

            function resolve_clipboard_paste_command() {
              case "''${XDG_SESSION_TYPE:-}" in
                wayland)
                  if command -v wl-paste >/dev/null 2>&1; then
                    REPLY='wl-paste --no-newline'
                    return 0
                  fi
                  ;;
                x11)
                  if command -v xclip >/dev/null 2>&1; then
                    REPLY='xclip -selection clipboard -o'
                    return 0
                  fi
                  ;;
              esac

              if command -v wl-paste >/dev/null 2>&1; then
                REPLY='wl-paste --no-newline'
              elif command -v xclip >/dev/null 2>&1; then
                REPLY='xclip -selection clipboard -o'
              else
                printf 'No clipboard paste command available\n' >&2
                return 1
              fi
            }
          '';
    in
    {
      home = {
        sessionPath = [
          "$HOME/.local/bin"
          "${config.xdg.dataHome}/go/bin"
        ];
        shell.enableZshIntegration = true;
        sessionVariables = {
          CLICOLOR = 1;
          DOCKER_BUILDKIT = 1;
          FZF_DEFAULT_OPTS = "--height 30% --layout=reverse";
        };

        shellAliases = {
          d = "docker";
          dc = "docker compose";
          dcd = "docker compose down";
          dcl = "docker compose logs";
          dcr = "docker compose down && docker compose up -d";
          dcu = "docker compose up -d";
          de = "docker exec";
          di = "docker image";
          diins = "docker image inspect";
          dins = "docker inspect";
          dirm = "docker image rm -f";
          dl = "docker logs";
          dn = "docker network";
          dnins = "docker network inspect";
          dp = "docker pull";
          dr = "docker run";
          dre = "docker restart";
          drm = "docker rm -f";
          dst = "docker stop";
          dv = "docker volume";
          dvi = "docker volume inspect";
          dvrm = "docker volume rm -f";
          g = "git";
          grep = "grep --color=auto";
          ip = "ip -c";
          jsonless = "bat -pl json";
          kb = "kubecolor";
          kns = "kubens";
          ku = "kubectx -u";
          kx = "kubectx";
          l = "ls --color=auto -alh";
          ll = "ls --color=auto -lh";
          ls = "ls --color=auto";
          man = "batman";
          ncdu = "ncdu --color dark";
          py = "python3";
          sl = "ls";
          sudo = "sudo ";
          unxz = "xz -d -T0";
          unzstd = "zstd -d -T0";
          vim = "nvim";
          xz = "xz -T0";
          zstd = "zstd -T0";
        };
      };

      home.packages = with pkgs; [
        starship
        vivid
      ];

      programs = {
        btop.enable = true;
        carapace.enable = true;
        direnv = {
          enable = true;
          package = pkgs.unstable.direnv;
          # config = {};
          nix-direnv.enable = true;
        };

        fastfetch.enable = true;
        fd.enable = true;

        fzf = {
          enable = true;
          changeDirWidgetCommand = "fd --type d";
          # colors = {};
        };

        # TODO: see what can be done declaratively e.g. key management/provisioning per-host.
        # probably needs factoring out to user-specific config.
        # gpg = {};

        htop = {
          enable = true;
          settings = {
            color_scheme = 6;
            cpu_count_from_one = 0;
            delay = 15;
            fields = with config.lib.htop.fields; [
              PID
              USER
              PRIORITY
              NICE
              M_SIZE
              M_RESIDENT
              M_SHARE
              STATE
              PERCENT_CPU
              PERCENT_MEM
              TIME
              COMM
            ];
            highlight_base_name = 1;
            highlight_megabytes = 1;
            highlight_threads = 1;
          }
          // (
            with config.lib.htop;
            leftMeters [
              (bar "AllCPUs2")
              (bar "Memory")
              (bar "Swap")
              (text "Zram")
            ]
          )
          // (
            with config.lib.htop;
            rightMeters [
              (text "Tasks")
              (text "LoadAverage")
              (text "Uptime")
              (text "Systemd")
            ]
          );
        };

        # intelli-shell.enable = true;
        jq.enable = true;
        less.enable = true;
        lesspipe.enable = true;

        man = {
          enable = true;
          generateCaches = true;
        };

        rbw.enable = true;
        readline.enable = true;
        ripgrep.enable = true;
        ripgrep-all.enable = true;

        starship.enable = true;

        # taskwarrior.enable = true;
        # tealdeer.enable = true;

        vivid = {
          enable = true;
          activeTheme = "one-dark";
          colorMode = "24-bit";
          enableZshIntegration = true;
          themes = {
            one-dark = builtins.fetchurl {
              url = "https://raw.githubusercontent.com/sharkdp/vivid/2772c9dab8c0f214d3e09b08fe6291ec89086359/themes/one-dark.yml";
              sha256 = "03sari9dwq7hmy4w6fg7xzhb0k5x315dxycjmlp45nhk4a1ymk5d";
            };
          };
        };

        yazi.enable = true;

        zsh = {
          enable = true;
          enableCompletion = true;
          enableVteIntegration = true;
          antidote = {
            enable = true;
            useFriendlyNames = true;
            plugins = [
              "zsh-users/zsh-completions"
              "robbyrussell/oh-my-zsh path:plugins/ssh-agent"
              "zsh-users/zsh-history-substring-search"
            ];
          };
          dirHashes = { };
          dotDir = "${config.xdg.configHome}/zsh";
          history.size = 10000;
          history = {
            append = true;
            expireDuplicatesFirst = true;
            ignoreDups = true;
            ignoreSpace = true;
            path = "${config.xdg.stateHome}/.zsh_history";
            save = 10000;
            share = true;
          };
          initContent = lib.mkOrder 500 (
            zshInitPrelude
            + ''
                if [ -f "${config.xdg.configHome}/zsh/exports_local.zsh" ]; then
                  source "${config.xdg.configHome}/zsh/exports_local.zsh"
                fi

                ${clipboardHelpers}

              function copy() {
                local use_sudo=""
                local -a cmd

                while getopts 's' arg; do
                  case "''${arg}" in
                    's') use_sudo='1' ;;
                    *) ;;
                  esac
                done
                shift "$((OPTIND-1))"

                resolve_clipboard_copy_command || return 1
                cmd=($=REPLY)

                if [ -z "''${1}" ]; then
                  "''${cmd[@]}"
                else
                  if [ -n "''${use_sudo}" ]; then
                    sudo cat -- "''${1}" | tee /dev/tty | "''${cmd[@]}"
                  else
                    tee /dev/tty < "''${1}" | "''${cmd[@]}"
                  fi
                fi
              }

              function paste() {
                local append=""
                local use_sudo=""
                local -a cmd

                while getopts 'as' arg; do
                  case "''${arg}" in
                    'a') append='1' ;;
                    's') use_sudo='1' ;;
                    *) ;;
                  esac
                done
                shift "$((OPTIND-1))"

                if [ -z "''${1}" ]; then
                  printf 'No target file provided\n'
                  return 1
                else
                  resolve_clipboard_paste_command || return 1
                  cmd=($=REPLY)

                  if [ -n "''${use_sudo}" ]; then
                    if [ -n "''${append}" ]; then
                      "''${cmd[@]}" | sudo tee -a -- "''${1}"
                    else
                      "''${cmd[@]}" | sudo tee -- "''${1}"
                    fi
                  else
                    if [ -n "''${append}" ]; then
                      "''${cmd[@]}" | tee -a -- "''${1}"
                    else
                      "''${cmd[@]}" | tee -- "''${1}"
                    fi
                  fi
                fi
              }

              function pastebin() {
                local use_sudo=""
                local url=""

                while getopts 's' arg; do
                  case "''${arg}" in
                    's') use_sudo='1' ;;
                    *) ;;
                  esac
                done
                shift "$((OPTIND-1))"

                if [ $# -eq 0 ]; then
                  url="$(tee /dev/tty < /dev/stdin | curl -fsS -X PUT -d @- https://p.mort.coffee)"
                else
                  if [ -n "''${use_sudo}" ]; then
                    url="$(sudo curl -fsS --upload-file "''${1}" https://p.mort.coffee)"
                  else
                    url="$(curl -fsS --upload-file "''${1}" https://p.mort.coffee)"
                  fi
                fi

                if [ -n "''${url}" ]; then
                  copy <<< "''${url}"
                  printf '%s\n' "''${url}"
                fi
              }
            ''
          );
        };
      };

      xdg.configFile = {
        "starship.toml".source = ./files/starship.toml;

        # Home Manager's vivid module does not expose the whole vivid config
        # surface, so keep the checked-in vivid files as the source of truth.
        "vivid/filetypes.yml".source = ./files/vivid-filetypes.yml;
      };

    };
}
