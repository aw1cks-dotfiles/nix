{ inputs, lib, ... }:
{
  aw1cks.modules.home.neovim =
    { config, pkgs, ... }:
    let
      configDir = ./files;
      diffviewPackage = pkgs.vimUtils.buildVimPlugin {
        pname = "diffview-plus.nvim";
        version = "0.39";
        src = pkgs.fetchFromGitHub {
          owner = "dlyongemallo";
          repo = "diffview-plus.nvim";
          tag = "v0.39";
          hash = "sha256-0Zu2HPU9rzsyIOVLPWB9ABmfu5UffYkJtkIQUtBLVOs=";
        };
        # Internal modules require the globals initialized by plugin/diffview.lua.
        nvimRequireCheck = [ "diffview" ];
        doInstallCheck = true;
        installCheckPhase = ''
          runHook preInstallCheck
          export HOME="$TMPDIR"
          ${pkgs.neovim-unwrapped}/bin/nvim --headless -u NONE -i NONE \
            --cmd "set rtp^=$out" \
            -c "runtime plugin/diffview.lua" \
            -c "lua
              local ok, err = pcall(function()
                require('diffview').setup({
                  view = { merge_tool = { layout = 'diff3_mixed' } },
                })
                assert(vim.fn.exists(':DiffviewOpen') == 2)
                for _, path in ipairs(vim.fn.glob('$out/lua/**/*.lua', false, true)) do
                  if not path:find('/tests/', 1, true) then
                    local module = path:sub(#'$out/lua/' + 1, -5):gsub('/', '.'):gsub('%.init$', [[]])
                    require(module)
                  end
                end
              end)
              if not ok then
                vim.api.nvim_err_writeln(err)
                vim.cmd('cquit')
              end" \
            -c "qa!"
          runHook postInstallCheck
        '';
      };
      rustToolchains = import ../../dev/_rust-toolchains.nix {
        inherit
          config
          inputs
          lib
          pkgs
          ;
      };
      mermaidRendererPackage =
        inputs.mermaid-rs-renderer.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          {
            buildInputs =
              lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                pkgs.fontconfig
                pkgs.freetype
              ]
              ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.libiconv ];
          };
      mmdrLightConfig = ./files/mmdr-light.json;
      mmdrDarkConfig = ./files/mmdr-dark.json;
      mmdcScript = pkgs.replaceVars ./files/mmdc.sh {
        mmdrBin = "${mermaidRendererPackage}/bin/mmdr";
        inherit mmdrDarkConfig mmdrLightConfig;
      };
      mmdcWrapper = pkgs.writeShellApplication {
        name = "mmdc";
        runtimeInputs = [
          mermaidRendererPackage
          pkgs.gawk
        ];
        text = ''
          exec ${pkgs.runtimeShell} ${mmdcScript} "$@"
        '';
      };
      ompAcpConfig = pkgs.writeText "omp-avante-acp.yml" ''
        tools:
          approval:
            bash: allow
      '';
      avanteConfig = pkgs.replaceVars ./files/plugins/avante.lua {
        omp = "${config.programs.omp.package}/bin/omp";
        ompAcpConfig = ompAcpConfig;
      };
      # Keep validation independent of upstream's module; see docs/neovim.md.
      treesitterQueryCheck =
        pkgs.runCommand "neovim-treesitter-query-check"
          { nativeBuildInputs = [ config.programs.neovim.package ]; }
          ''
            export HOME="$TMPDIR"
            mkdir -p "$TMPDIR/site"
            ln -s ${
              config.xdg.dataFile."${config.programs.lazyvim.appName}/site/parser".source
            } "$TMPDIR/site/parser"
            ln -s ${
              config.xdg.dataFile."${config.programs.lazyvim.appName}/site/queries".source
            } "$TMPDIR/site/queries"
            nvim --clean -l ${./_treesitter-query-check.lua} "$TMPDIR/site"
            touch "$out"
          '';
    in
    {
      imports = [ inputs.lazyvim-nix.homeManagerModules.default ];

      config = {
        programs.neovim = {
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          extraWrapperArgs = lib.optionals (lib.hasAttrByPath [ "aw1cks" "rust" ] config) [
            "--set-default"
            "RUSTUP_HOME"
            config.home.sessionVariables.RUSTUP_HOME
          ];
        };

        home.checks = lib.optionals (
          config.programs.lazyvim.enable && pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform
        ) [ treesitterQueryCheck ];

        home.sessionVariables = {
          # We use an absolute path for SUDO_EDITOR.
          # home-manager hosts will not have the nix PATH setup and silently fall back.
          # NOTE: this can go stale when a new HM generation is built.
          # TODO: add a guard condition to avoid this for darwin/nixos
          SUDO_EDITOR = "${config.programs.neovim.finalPackage}/bin/nvim";
          VISUAL = "nvim";
        };

        programs.lazyvim = {
          enable = true;
          appName = "nvim";
          configFiles = configDir;
          pluginSource = "latest";

          # Upstream still scans installed HOME instead of configFiles and misses
          # implicit completion dependencies (#109). Provision only the gaps;
          # optional fragments must not enable plugins the Lua profile removed.
          # Keep native Avante/Blink packaging from nixpkgs. See docs/neovim.md.
          plugins.nix-managed = inputs.lazyvim-nix.lib.lazyConfig (
            map
              (
                spec:
                {
                  dev = false;
                  pin = true;
                  optional = true;
                }
                // spec
              )
              [
                {
                  plugin = "yetone/avante.nvim";
                  dir = "${pkgs.vimPlugins.avante-nvim}";
                }
                {
                  plugin = "nyoom-engineering/oxocarbon.nvim";
                  dir = "${pkgs.vimPlugins.oxocarbon-nvim}";
                }
                {
                  plugin = "dlyongemallo/diffview-plus.nvim";
                  dir = "${diffviewPackage}";
                }
                {
                  plugin = "stevearc/dressing.nvim";
                  dir = "${pkgs.vimPlugins.dressing-nvim}";
                  lazy = true;
                }
                {
                  plugin = "HakonHarnes/img-clip.nvim";
                  dir = "${pkgs.vimPlugins.img-clip-nvim}";
                  lazy = true;
                }
                {
                  plugin = "saghen/blink.cmp";
                  dir = "${pkgs.vimPlugins.blink-cmp}";
                }
                {
                  plugin = "rafamadriz/friendly-snippets";
                  dir = "${pkgs.vimPlugins.friendly-snippets}";
                  lazy = true;
                }
              ]
          );

          extras = {
            coding."mini-surround".enable = true;
            editor = {
              navic.enable = true;
              "neo-tree".enable = true;
              outline.enable = true;
            };
            lang = {
              docker = {
                enable = true;
                installDependencies = true;
              };
              dotnet.enable = true;
              git.enable = true;
              go = {
                enable = true;
                installDependencies = true;
              };
              helm = {
                enable = true;
                installDependencies = true;
              };
              json.enable = true;
              kotlin = {
                enable = true;
                installDependencies = true;
              };
              markdown = {
                enable = true;
                installDependencies = true;
              };
              nix.enable = false;
              python.enable = true;
              rust = {
                enable = true;
                installDependencies = true;
              };
              sql = {
                enable = true;
                installDependencies = true;
              };
              terraform = {
                enable = true;
                installDependencies = true;
              };
              toml = {
                enable = true;
                installDependencies = true;
              };
              yaml.enable = true;
            };
            util = {
              gh.enable = true;
              gitui = {
                enable = true;
                installDependencies = true;
              };
              octo.enable = true;
            };
          };

          extraPackages =
            (import ../../dev/_language-servers.nix {
              inherit pkgs;
              inherit (rustToolchains) rust-analyzer;
            })
            ++ rustToolchains.editorPackages
            ++ (with pkgs; [
              alejandra
              bacon
              csharpier
              curl
              fd
              dotnet-sdk
              fantomas
              fzf
              findutils
              fish
              gh
              git
              go
              golangci-lint
              gofumpt
              gomodifytags
              gotools
              gradle
              gnused
              gnutar
              ghostscript
              hadolint
              hclfmt
              impl
              imagemagick
              jq
              ktlint
              lazygit
              markdown-toc
              markdownlint-cli2
              mmdcWrapper
              mercurial
              nixfmt
              nodejs
              netcoredbg
              prettier
              python3
              ripgrep
              shellcheck
              shfmt
              sqlite
              sqlfluff
              statix
              stylua
              tectonic
              terraform
              trash-cli
              tflint
              tree-sitter
              mermaidRendererPackage
              stdenv.cc
              xclip
            ]);

          treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
            cpp
            c_sharp
            css
            dockerfile
            git_config
            git_rebase
            gitattributes
            gitcommit
            gitignore
            gotmpl
            groovy
            hcl
            jq
            kotlin
            latex
            make
            mermaid
            nix
            perl
            ruby
            scss
            sql
            svelte
            terraform
            typst
            vue
            xml
          ];
        };

        xdg.configFile."nvim/lua/plugins/avante.lua".source = lib.mkForce avanteConfig;
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      checks.neovim-plugin-loading =
        pkgs.runCommand "neovim-plugin-loading" { nativeBuildInputs = [ pkgs.neovim-unwrapped ]; }
          ''
            export HOME="$TMPDIR"
            export XDG_DATA_HOME="$TMPDIR/data"
            export XDG_STATE_HOME="$TMPDIR/state"
            export XDG_CACHE_HOME="$TMPDIR/cache"
            export LAZY_PLUGIN=${pkgs.vimPlugins.lazy-nvim}
            export COMPAT_FILE=${./files/plugins/000-lazy-bootstrap.lua}
            mkdir -p "$TMPDIR/dev"
            ln -s ${pkgs.vimPlugins.trouble-nvim} "$TMPDIR/dev/folke--trouble.nvim"
            export PLUGIN_DIR="$TMPDIR/dev/folke--trouble.nvim"
            export RESULT_FILE="$TMPDIR/dev-path-result"
            nvim --headless -u ${./_lazy-plugin-check.lua}
            test -s "$RESULT_FILE"
            export PLUGIN_DIR=${pkgs.vimPlugins.trouble-nvim}
            export RESULT_FILE="$TMPDIR/store-path-result"
            nvim --headless -u ${./_lazy-plugin-check.lua}
            test -s "$RESULT_FILE"
            touch "$out"
          '';
    };
}
