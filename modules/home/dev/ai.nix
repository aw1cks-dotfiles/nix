# AI coding tools — from nix-upstream/modules/development/ai.nix
{ inputs, ... }:
{
  aw1cks.modules.home.ai =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.modules.ai;
      mkModelTierOption =
        {
          description,
          model,
        }:
        lib.mkOption {
          type = lib.types.str;
          default = model;
          inherit description;
        };
      frontier_model = cfg.models.frontier;
      premium_model = cfg.models.premium;
      standard_model = cfg.models.standard;
      small_model = cfg.models.small;
    in
    {
      options.modules.ai = {
        models = lib.mkOption {
          type = lib.types.submodule {
            options = {
              frontier = mkModelTierOption {
                description = "Frontier model used for the most demanding planning and review tasks.";
                model = "openai-codex/gpt-6-astra:xhigh";
              };
              premium = mkModelTierOption {
                description = "Premium model used for primary interactive work.";
                model = "openai-codex/gpt-6.1-sol:high";
              };
              standard = mkModelTierOption {
                description = "Standard model used for general delegated work.";
                model = "openai-codex/gpt-6.1-sol:medium";
              };
              small = mkModelTierOption {
                description = "Small model used for exploration and lightweight background work.";
                model = "openai-codex/gpt-6-luna:low";
              };
            };
          };
          default = { };
          description = "Model tiers feeding the shared OMP defaults; values are OMP model selectors with an optional thinking suffix.";
        };

        mcp = lib.mkOption {
          type = lib.types.anything;
          description = "MCP home-manager configuration";

          default = {
            enable = true;
            servers = {
              context7 = {
                url = "https://mcp.context7.com/mcp";
                headers = {
                  CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}";
                };
              };
            };
          };
        };

        skillsSource = lib.mkOption {
          type = lib.types.path;
          default = ./files/agents/skills;
          description = "Bundled shared agent skills directory exposed as a stable downstream contract.";
        };

        omp = lib.mkOption {
          type = lib.types.submoduleWith {
            shorthandOnlyDefinesConfig = true;
            # Pass pkgs explicitly: submodule modules resolve unset args via
            # `_module.args`, which needs the outer config fixpoint and recurses
            # when the option is forced from config evaluation.
            specialArgs = { inherit pkgs; };
            modules = [
              (
                { lib, pkgs, ... }:
                {
                  freeformType = lib.types.attrsOf lib.types.anything;
                  config = {
                    enable = lib.mkDefault true;
                    # Build with OMP's own pinned Rust toolchain. The
                    # llm-agents overlay uses stable rustc, but OMP uses
                    # unstable standard-library APIs.
                    package = lib.mkDefault inputs.oh-my-pi.packages.${pkgs.stdenv.hostPlatform.system}.omp;

                    # Per-key defaults: a downstream `settings` attrset merges
                    # key-by-key (last one wins per key) instead of replacing
                    # this whole block, so private overlays can override the
                    # model routing without restating shared UI preferences.
                    settings = {
                      # State markers: without these every switch re-runs
                      # onboarding and re-prompts for dev consent.
                      setupVersion = lib.mkDefault 2;
                      dev.autoqaConsent = lib.mkDefault "granted";

                      theme.dark = lib.mkDefault "oxocarbon-dark";
                      composer.shape = lib.mkDefault "rail";
                      statusLine = lib.mkDefault {
                        preset = "nerd";
                        contextLine = "percentage";
                      };
                      display = lib.mkDefault {
                        cacheMissMarker = true;
                        showTurnTime = true;
                        showTokenUsage = true;
                      };
                      tui.tight = lib.mkDefault true;
                      terminal.showProgress = lib.mkDefault true;
                      defaultThinkingLevel = lib.mkDefault "auto";
                      extendedContext = lib.mkDefault true;
                      advisor.enabled = lib.mkDefault false;
                      tools.approvalMode = lib.mkDefault "write";
                      github.enabled = lib.mkDefault true;
                      astGrep.enabled = lib.mkDefault true;

                      # Keep inspection on structured tools while preserving
                      # commands whose native HTTP or text-transform semantics
                      # are required. GitHub requests retain their API routing.
                      bashInterceptor = {
                        enabled = lib.mkDefault true;
                        patterns = lib.mkDefault [
                          {
                            pattern = "^\\s*(grep|rg|ag|ack)\\b";
                            tool = "grep";
                            message = "Use the structured grep tool instead; it returns file and line context without shell parsing.";
                          }
                          {
                            pattern = "^\\s*(cat|head|tail|less|more)\\b";
                            tool = "read";
                            message = "Use read with a line-range selector instead; it preserves file context and avoids truncated shell output.";
                          }
                          {
                            pattern = "^\\s*gh\\s+(issue|pr)\\s+(view|list|search|checkout|create|diff)\\b";
                            tool = "github";
                            message = "Use the github tool instead; it wraps gh with structured output and caching.";
                          }
                        ];
                      };

                      # Keep privilege escalation gated, including in yolo
                      # sessions. Auto-approve only explicit, read-only Git
                      # forms; broad subcommands such as `git branch *` also
                      # include mutating operations.
                      bash.patterns = lib.mkDefault [
                        {
                          match = "sudo *";
                          approval = "prompt";
                        }
                        {
                          match = "git status";
                          approval = "allow";
                        }
                        {
                          match = "git status --short";
                          approval = "allow";
                        }
                        {
                          match = "git status --short --branch";
                          approval = "allow";
                        }
                        {
                          match = "git status --porcelain";
                          approval = "allow";
                        }
                        {
                          match = "git status --porcelain=v1";
                          approval = "allow";
                        }
                        {
                          match = "git status --porcelain=v2";
                          approval = "allow";
                        }
                        {
                          match = "git diff --no-ext-diff --no-textconv";
                          approval = "allow";
                        }
                        {
                          match = "git diff --no-ext-diff --no-textconv -- *";
                          approval = "allow";
                        }
                        {
                          match = "git diff --cached --no-ext-diff --no-textconv";
                          approval = "allow";
                        }
                        {
                          match = "git diff --cached --no-ext-diff --no-textconv -- *";
                          approval = "allow";
                        }
                        {
                          match = "git diff --check";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --show-toplevel";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --is-inside-work-tree";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --abbrev-ref HEAD";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --verify *";
                          approval = "allow";
                        }
                        {
                          match = "git merge-base *";
                          approval = "allow";
                        }
                        {
                          match = "git branch --show-current";
                          approval = "allow";
                        }
                        {
                          match = "git branch --list";
                          approval = "allow";
                        }
                        {
                          match = "git branch --list *";
                          approval = "allow";
                        }
                        {
                          match = "git branch -r";
                          approval = "allow";
                        }
                        {
                          match = "git symbolic-ref --short HEAD";
                          approval = "allow";
                        }
                        {
                          match = "git symbolic-ref refs/remotes/origin/HEAD";
                          approval = "allow";
                        }
                        {
                          match = "git log";
                          approval = "allow";
                        }
                        {
                          match = "git log --oneline";
                          approval = "allow";
                        }
                        {
                          match = "git log --oneline --decorate";
                          approval = "allow";
                        }
                        {
                          match = "git log --oneline --decorate --graph --all";
                          approval = "allow";
                        }
                        {
                          match = "git show --no-ext-diff --no-textconv";
                          approval = "allow";
                        }
                        {
                          match = "git ls-files";
                          approval = "allow";
                        }
                        {
                          match = "git ls-files -- *";
                          approval = "allow";
                        }
                        {
                          match = "git worktree list";
                          approval = "allow";
                        }
                        {
                          match = "git remote";
                          approval = "allow";
                        }
                        {
                          match = "git remote -v";
                          approval = "allow";
                        }
                        {
                          match = "git remote get-url *";
                          approval = "allow";
                        }
                        {
                          match = "git config --get *";
                          approval = "allow";
                        }
                        {
                          match = "git config --get-all *";
                          approval = "allow";
                        }
                        {
                          match = "git config --get-regexp *";
                          approval = "allow";
                        }
                      ];

                      modelRoles = lib.mkDefault {
                        default = premium_model;
                        smol = small_model;
                        slow = frontier_model;
                        vision = standard_model;
                        plan = frontier_model;
                        designer = premium_model;
                        commit = small_model;
                        tiny = small_model;
                        task = standard_model;
                        advisor = frontier_model;
                      };

                      # Per-subkey defaults so a downstream `task.isolation.*`
                      # choice merges instead of replacing this block.
                      task.isolation.mode = lib.mkDefault "auto";
                      task.maxRecursionDepth = lib.mkDefault 1;
                      task.agentModelOverrides = lib.mkDefault {
                        # Permit one layer of delegation and strip task spawning
                        # from those child agents.
                        scout = "@smol";
                        librarian = "@smol";
                        sonic = "@smol";
                        task = "@task";
                        designer = "@designer";
                        reviewer = "@slow";
                        security-reviewer = "@slow";
                      };
                    };
                  };
                }
              )
            ];
          };
          default = { };
          description = "OMP (oh-my-pi) home-manager configuration, forwarded to programs.omp";
        };
      };

      config = {
        home.packages = with pkgs.llm-agents; [
          claude-code
        ];

        programs.mcp = cfg.mcp;
        programs.omp = cfg.omp;
        home.file = lib.mkIf cfg.omp.enable {
          ".omp/agent/themes/oxocarbon-dark.json".source = ./files/agents/omp/themes/oxocarbon-dark.json;
        };
      };
    };
}
