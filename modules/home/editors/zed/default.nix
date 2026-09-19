{
  inputs,
  lib,
  ...
}:
{
  aw1cks.modules.home.zed =
    {
      config,
      pkgs,
      ...
    }:
    let
      ompCommand = "${config.programs.omp.package}/bin/omp";
      zedPackage = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.zed-editor;
      serverBinary = package: executable: arguments: {
        path = "${package}/bin/${executable}";
        inherit arguments;
      };
      yamlSettings = {
        format.enable = true;
        validate = true;
        hover = true;
        completion = true;
        schemaStore.enable = true;
        # Auto-discovery encodes private API groups/kinds in public schema URLs.
        kubernetesCRDStore.enable = false;
        customTags = [
          "!reference sequence"
          "!unsafe scalar"
        ];

      };
      helmSettings = {
        # Keep Helm execution explicit; the tasks below lint/render on demand.
        helmLint.enabled = false;
        yamlls = {
          enabled = true;
          path = "${pkgs.yaml-language-server}/bin/yaml-language-server";
          config = yamlSettings;
        };
      };
      savedTask = label: text: {
        inherit label;
        # Zed concatenates task args as shell fragments. Read file paths from the
        # environment inside a checked wrapper instead of interpolating them there.
        command = lib.getExe (
          pkgs.writeShellApplication {
            name = "zed-task";
            inherit text;
          }
        );
        args = [ ];
        cwd = "$ZED_WORKTREE_ROOT";
        save = "none";
        allow_concurrent_runs = false;
        reveal = "always";
        hide = "never";
      };
    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "zed" ''
          exec zeditor "$@"
        '')
      ];

      programs.zed-editor = {
        enable = true;
        defaultEditor = false;
        # Zed 1.3.6 accepts agent.terminal_init_command in settings.json but
        # cannot execute it or discover current ChatGPT subscription models.
        package = zedPackage;

        # These tools must also work from a GUI launch, independently of Neovim's PATH.
        # Keep plain Helm out of this PATH: the Kubernetes module supplies plugin-wrapped Helm.
        extraPackages = with pkgs; [
          alejandra
          bash-language-server
          cargo
          clippy
          dotnet-sdk
          fsautocomplete
          go
          golangci-lint
          gopls
          hadolint
          helm-ls
          lua-language-server
          markdownlint-cli2
          marksman
          nixd
          prettier
          ruff
          rust-analyzer
          rustc
          rustfmt
          shellcheck
          shfmt
          sqlfluff
          statix
          stylua
          terraform
          terraform-ls
          tflint
          tombi
          ty
          yaml-language-server
        ];

        extensions = [
          "nix"
          "dockerfile"
          "terraform"
          "helm"
          "toml"
          "tombi"
          "lua"
          "marksman"
          "fsharp"
          "html"
          "csharp"
          "kotlin"
          "sql"
          "mermaid"
          "oxocarbon"
        ];

        userSettings = lib.mkMerge [
          {
            vim_mode = true;
            # Neovim leaves 'clipboard' empty: use explicit "+ registers for system copy/paste.
            vim.use_system_clipboard = "never";
            relative_line_numbers = "enabled";

            # Match the current Neovim policy: formatting remains explicit.
            format_on_save = "off";
            hard_tabs = false;
            tab_size = 4;

            buffer_font_family = "CaskaydiaMono Nerd Font";
            ui_font_family = "SF Pro Display Nerd Font";
            terminal.font_family = "CaskaydiaMono Nerd Font";

            theme = "Oxocarbon Dark (IBM Carbon)";

            telemetry = {
              diagnostics = false;
              metrics = false;
            };

            # Template YAML is not ordinary YAML. Keep these associations chart-scoped.
            file_types.Helm = [
              "**/charts/*/templates/**/*.yaml"
              "**/charts/*/templates/**/*.yml"
              "**/charts/*/templates/**/*.tpl"
              "**/charts/*/values*.yaml"
              "**/charts/*/values*.yml"
            ];

            languages = {
              Nix = {
                tab_size = 2;
                language_servers = [
                  "nixd"
                  "!nil"
                ];
                formatter = {
                  external = {
                    command = "${pkgs.alejandra}/bin/alejandra";
                    arguments = [
                      "--quiet"
                      "--"
                    ];
                  };
                };
              };
              Lua = {
                tab_size = 2;
                language_servers = [ "lua-language-server" ];
                formatter.external = {
                  command = "${pkgs.stylua}/bin/stylua";
                  arguments = [
                    "--respect-ignores"
                    "--stdin-filepath"
                    "{buffer_path}"
                    "-"
                  ];
                };
              };
              Python = {
                tab_size = 4;
                language_servers = [
                  "ty"
                  "ruff"
                ];
                formatter.language_server.name = "ruff";
                code_actions_on_format."source.organizeImports.ruff" = true;
              };
              Go = {
                hard_tabs = true;
                tab_size = 4;
                language_servers = [ "gopls" ];
                formatter = "language_server";
                code_actions_on_format."source.organizeImports" = true;
              };
              "Go Mod" = {
                hard_tabs = true;
                tab_size = 4;
              };
              "Go Work" = {
                hard_tabs = true;
                tab_size = 4;
              };
              Rust.language_servers = [ "rust-analyzer" ];
              FSharp = {
                tab_size = 4;
                language_servers = [ "fsautocomplete" ];
                formatter = "language_server";
              };
              Markdown = {
                tab_size = 4;
                soft_wrap = "editor_width";
                language_servers = [ "marksman" ];
                formatter.external = {
                  command = "${pkgs.prettier}/bin/prettier";
                  arguments = [
                    "--stdin-filepath"
                    "{buffer_path}"
                  ];
                };
              };
              TOML = {
                tab_size = 2;
                language_servers = [ "tombi" ];
                formatter.language_server.name = "tombi";
              };
              "Shell Script" = {
                tab_size = 4;
                language_servers = [ "bash-language-server" ];
                formatter.external = {
                  command = "${pkgs.shfmt}/bin/shfmt";
                  arguments = [
                    "-filename"
                    "{buffer_path}"
                  ];
                };
              };
              SQL = {
                tab_size = 4;
                # The project must choose its SQL dialect/templater in .sqlfluff.
                formatter.external = {
                  command = "${pkgs.sqlfluff}/bin/sqlfluff";
                  arguments = [
                    "format"
                    "--stdin-filename"
                    "{buffer_path}"
                    "-"
                  ];
                };
              };
              YAML = {
                tab_size = 2;
                language_servers = [ "yaml-language-server" ];
                formatter = "language_server";
              };
              Helm = {
                tab_size = 2;
                language_servers = [ "helm" ];
              };
              "Docker Compose".tab_size = 2;
              Terraform = {
                tab_size = 2;
                formatter = "language_server";
              };
              "Terraform Vars" = {
                tab_size = 2;
                formatter = "language_server";
              };
              HCL.tab_size = 2;
              JSON.tab_size = 2;
              JSONC.tab_size = 2;
              JavaScript.tab_size = 2;

              TypeScript.tab_size = 2;
              TSX.tab_size = 2;
              HTML.tab_size = 2;
              CSS.tab_size = 2;
              SCSS.tab_size = 2;
              C.tab_size = 2;
              "C++".tab_size = 2;

            };

            lsp = {
              nixd.binary = serverBinary pkgs.nixd "nixd" [ ];
              "lua-language-server" = {
                binary = serverBinary pkgs.lua-language-server "lua-language-server" [ ];
                settings.Lua.format.enable = false;
              };
              ty.binary = serverBinary pkgs.ty "ty" [ "server" ];
              ruff.binary = serverBinary pkgs.ruff "ruff" [ "server" ];
              gopls = {
                binary = serverBinary pkgs.gopls "gopls" [ ];
                initialization_options = {
                  gofumpt = true;
                  staticcheck = true;
                };
              };
              "rust-analyzer".binary = serverBinary pkgs.rust-analyzer "rust-analyzer" [ ];
              fsautocomplete.binary = serverBinary pkgs.fsautocomplete "fsautocomplete" [
                "--adaptive-lsp-server-enabled"
              ];
              marksman.binary = serverBinary pkgs.marksman "marksman" [ "server" ];
              tombi.binary = serverBinary pkgs.tombi "tombi" [ "lsp" ];
              "bash-language-server" = {
                binary = serverBinary pkgs.bash-language-server "bash-language-server" [ "start" ];
                settings.bashIde = {
                  shellcheckPath = "${pkgs.shellcheck}/bin/shellcheck";
                  shfmt.path = "${pkgs.shfmt}/bin/shfmt";
                };
              };
              "terraform-ls".binary = serverBinary pkgs.terraform-ls "terraform-ls" [ "serve" ];
              "yaml-language-server" = {
                binary = serverBinary pkgs.yaml-language-server "yaml-language-server" [ "--stdio" ];
                settings.yaml = yamlSettings;
              };
              helm = {
                binary = serverBinary pkgs.helm-ls "helm_ls" [ "serve" ];
                settings = helmSettings;
              };
              # Helm extension 0.0.6 reads this older key; 0.0.8 reads lsp.helm.settings.
              helm_ls.settings."helm-ls" = helmSettings;
            };
          }

          (lib.mkIf config.programs.omp.enable {
            agent_servers.omp = {
              type = "custom";
              command = ompCommand;
              args = [ "acp" ];
              env = { };
            };

            agent = {
              terminal_init_command = ompCommand;
              notify_when_agent_waiting = "primary_screen";
              play_sound_when_agent_done = "always";
            };
          })
        ];

        # Manual, disk-based checks. No apply/init/update hooks or automatic cluster access.
        userTasks = [
          (savedTask "Lint: Hadolint (saved Dockerfile)" ''
            exec ${pkgs.hadolint}/bin/hadolint "$ZED_FILE"
          '')
          (savedTask "Lint: Markdown (saved file)" ''
            exec ${pkgs.markdownlint-cli2}/bin/markdownlint-cli2 --no-globs ":$ZED_FILE"
          '')
          (savedTask "Lint: SQLFluff (saved file, project dialect)" ''
            exec ${pkgs.sqlfluff}/bin/sqlfluff lint "$ZED_FILE"
          '')
          (savedTask "Lint: Go (saved worktree/module)" ''
            exec ${pkgs.golangci-lint}/bin/golangci-lint run
          '')
          (savedTask "Lint: Statix (saved worktree)" ''
            exec ${pkgs.statix}/bin/statix check .
          '')
          (savedTask "Lint: ShellCheck (saved file)" ''
            exec ${pkgs.shellcheck}/bin/shellcheck "$ZED_FILE"
          '')
          (
            (savedTask "Terraform: validate (saved current module)" ''
              exec ${pkgs.terraform}/bin/terraform validate -no-color
            '')
            // {
              cwd = "$ZED_DIRNAME";
            }
          )
          (
            (savedTask "Terraform: TFLint (saved current module)" ''
              exec ${pkgs.tflint}/bin/tflint
            '')
            // {
              cwd = "$ZED_DIRNAME";
            }
          )

          (
            (savedTask "Kustomize: build (open kustomization.yaml first)" ''
              test -f kustomization.yaml || test -f kustomization.yml || test -f Kustomization || {
                echo "Open a file in the Kustomize root/overlay first." >&2; exit 1;
              }
              exec ${pkgs.kustomize}/bin/kustomize build .
            '')
            // {
              cwd = "$ZED_DIRNAME";
            }
          )
        ];

        # LazyVim/Snacks parity; plugin equivalents and limitations: docs/zed-parity.md.
        userKeymaps = [
          {
            context = "Editor && mode == full && vim_mode == normal && !menu";
            bindings = {
              "space space" = "file_finder::Toggle";
              "space f f" = "file_finder::Toggle";
              "space ," = "tab_switcher::ToggleAll";
              "space f b" = "tab_switcher::ToggleAll";
              "space f p" = "projects::OpenRecent";
              "space f n" = "workspace::NewFile";
              "space e" = "project_panel::Toggle";
              "space f e" = "project_panel::Toggle";

              "space /" = "pane::DeploySearch";
              "space s g" = "pane::DeploySearch";
              "space s b" = "buffer_search::Deploy";
              "space s s" = "outline::Toggle";
              "space s shift-s" = "project_symbols::Toggle";
              "space :" = "command_palette::Toggle";
              "space s shift-c" = "command_palette::Toggle";
              "space s k" = "zed::OpenKeymap";
              "space s shift-r" = "workspace::ReopenLastPicker";
              "space c l" = "task::Spawn";

              "shift-h" = "pane::ActivatePreviousItem";
              "shift-l" = "pane::ActivateNextItem";
              "space b b" = "pane::AlternateFile";
              "space `" = "pane::AlternateFile";
              "space b d" = "pane::CloseActiveItem";
              "space b o" = "pane::CloseOtherItems";
              "space -" = "pane::SplitDown";
              "space |" = "pane::SplitRight";
              "space w d" = "pane::CloseActiveItem";
              "space w m" = "workspace::ToggleZoom";
              "ctrl-h" = "workspace::ActivatePaneLeft";
              "ctrl-j" = "workspace::ActivatePaneDown";
              "ctrl-k" = "workspace::ActivatePaneUp";
              "ctrl-l" = "workspace::ActivatePaneRight";

              "space c f" = "editor::Format";
              "space c r" = "editor::Rename";
              "space c o" = "editor::OrganizeImports";
              "space c s" = "outline_panel::ToggleFocus";
              "space x x" = "diagnostics::Deploy";
              "space s d" = "diagnostics::Deploy";
              "g r" = "editor::FindAllReferences";
              "g shift-k" = "editor::ShowSignatureHelp";
              "] h" = "editor::GoToHunk";
              "[ h" = "editor::GoToPreviousHunk";
              "] ]" = "vim::GoToNextReference";
              "[ [" = "vim::GoToPreviousReference";

              "space g g" = "git_panel::ToggleFocus";
              "space g s" = "git_panel::ToggleFocus";
              "space g d" = "git::Diff";
              "space g h b" = "editor::BlameHover";
              "space g h shift-b" = "git::Blame";
              "space a a" = "agent::ToggleFocus";
              "space a f" = "agent::ToggleFocus";
              "space a n" = "agent::NewThread";
              "space f t" = "terminal_panel::Toggle";
              # Retain the existing Zed-only new-terminal shortcut.
              "space t t" = "workspace::NewTerminal";

              "g s d" = "vim::PushDeleteSurrounds";
              "g s r" = [
                "vim::PushChangeSurrounds"
                { }
              ];
            };
          }
          {
            context = "Editor && mode == full && (vim_mode == normal || vim_mode == visual) && !menu";
            bindings = {
              "space c a" = "editor::ToggleCodeActions";
              "space s r" = [
                "pane::DeploySearch"
                { replace_enabled = true; }
              ];
              "space g h p" = "editor::ToggleSelectedDiffHunks";
              "space g shift-b" = "editor::OpenPermalinkToLine";
              "space g shift-y" = "editor::CopyPermalinkToLine";
              # Free Zed's gs outline shortcut in both normal and visual modes.
              "g s" = null;
              "g s a" = [
                "vim::PushAddSurrounds"
                { }
              ];
            };
          }
          {
            context = "Editor && mode == full && vim_mode == visual && !menu";
            bindings = {
              "space c f" = "editor::FormatSelections";
              "space a a" = "agent::ToggleFocus";
              "space a e" = "assistant::InlineAssist";
            };
          }
          {
            context = "Editor && mode == full && (vim_mode == normal || vim_mode == visual || vim_mode == insert) && !menu";
            bindings = {
              "ctrl-s" = "workspace::Save";
              "alt-j" = "editor::MoveLineDown";
              "alt-k" = "editor::MoveLineUp";
            };
          }
          {
            context = "Editor && mode == full && vim_mode == insert && !menu";
            bindings."ctrl-k" = "editor::ShowSignatureHelp";
          }
          {
            # No Space leader in terminals: it must remain available to the shell.
            context = "Terminal || (Editor && mode == full && vim_mode == normal && !menu)";
            bindings = {
              "ctrl-/" = "terminal_panel::Toggle";
              "ctrl-_" = "terminal_panel::Toggle";
            };
          }
          {
            # not_editing prevents leader/file operations from intercepting names.
            context = "ProjectPanel && not_editing";
            bindings = {
              "space e" = "project_panel::Toggle";
              "space f e" = "project_panel::Toggle";
              "q" = "project_panel::Toggle";
              "a" = "project_panel::NewFile";
              "r" = "project_panel::Rename";
              "d" = [
                "project_panel::Trash"
                { skip_prompt = false; }
              ];
              "y" = "project_panel::Copy";
              "p" = "project_panel::Paste";
              "backspace" = "project_panel::SelectParent";
              "ctrl-s" = "project_panel::OpenSplitHorizontal";
              "ctrl-v" = "project_panel::OpenSplitVertical";
              "] g" = "project_panel::SelectNextGitEntry";
              "[ g" = "project_panel::SelectPrevGitEntry";
            };
          }
          {
            context = "OutlinePanel && not_editing";
            bindings."space c s" = "outline_panel::ToggleFocus";
          }
          {
            context = "Picker > Editor";
            bindings = {
              "ctrl-j" = "menu::SelectNext";
              "ctrl-k" = "menu::SelectPrevious";
            };
          }
        ];
      };
    };
}
