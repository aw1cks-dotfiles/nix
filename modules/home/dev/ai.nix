# AI coding tools — from nix-upstream/modules/development/ai.nix
{ ... }:
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
          opencodeModel,
          opencodeVariant ? null,
          ompModel,
        }:
        lib.mkOption {
          type = lib.types.submodule {
            options = {
              opencode = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    model = lib.mkOption {
                      type = lib.types.str;
                      description = "OpenCode provider/model identifier for this tier.";
                    };
                    variant = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      description = "Optional OpenCode model variant for this tier.";
                    };
                  };
                };
                description = "OpenCode model selection for this tier.";
              };
              omp = lib.mkOption {
                type = lib.types.str;
                description = "OMP model selector for this tier, including an optional thinking suffix.";
              };
            };
          };
          default = {
            opencode = {
              model = opencodeModel;
              variant = opencodeVariant;
            };
            omp = ompModel;
          };
          inherit description;
        };
      frontier_model = cfg.models.frontier;
      premium_model = cfg.models.premium;
      standard_model = cfg.models.standard;
      small_model = cfg.models.small;
      opencodeAgent = tier: lib.filterAttrs (_: value: value != null) tier.opencode;
      subagentPermission = {
        task = "deny";
      };
      readOnlyAgentPermission = subagentPermission // {
        edit = "deny";
      };
    in
    {
      options.modules.ai = {
        models = lib.mkOption {
          type = lib.types.submodule {
            options = {
              frontier = mkModelTierOption {
                description = "Frontier model used for the most demanding planning and review tasks.";
                opencodeModel = "openai/gpt-5.6-sol-pro";
                opencodeVariant = "high";
                # OMP's ChatGPT subscription provider does not expose the Pro model.
                ompModel = "openai-codex/gpt-5.6-sol:high";
              };
              premium = mkModelTierOption {
                description = "Premium model used for primary interactive work.";
                opencodeModel = "openai/gpt-5.6-sol";
                ompModel = "openai-codex/gpt-5.6-sol:medium";
              };
              standard = mkModelTierOption {
                description = "Standard model used for general delegated work.";
                opencodeModel = "openai/gpt-5.6-terra";
                ompModel = "openai-codex/gpt-5.6-terra:medium";
              };
              small = mkModelTierOption {
                description = "Small model used for exploration and lightweight background work.";
                opencodeModel = "openai/gpt-5.6-luna";
                ompModel = "openai-codex/gpt-5.6-luna";
              };
            };
          };
          default = { };
          description = "Provider-specific model tiers shared by the OpenCode and OMP defaults.";
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

        opencode = lib.mkOption {
          type = lib.types.submoduleWith {
            shorthandOnlyDefinesConfig = true;
            # See the omp option below for why pkgs is passed via specialArgs.
            specialArgs = { inherit pkgs; };
            modules = [
              (
                { lib, ... }:
                {
                  freeformType = lib.types.attrsOf lib.types.anything;

                  options = {
                    skillsSource = lib.mkOption {
                      type = lib.types.path;
                      default = ./files/opencode/skills;
                      description = "Bundled OpenCode skills directory exposed as a stable downstream contract.";
                    };

                    ollama = lib.mkOption {
                      type = lib.types.submodule {
                        options = {
                          enable = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Enable a local Ollama provider for OpenCode on this host.";
                          };

                          endpoint = lib.mkOption {
                            type = lib.types.str;
                            default = "localhost";
                            description = "Host name or address for the Ollama endpoint.";
                          };

                          models = lib.mkOption {
                            type = lib.types.attrsOf lib.types.anything;
                            default = { };
                            description = "Additional OpenCode model metadata exposed through the Ollama provider.";
                          };
                        };
                      };
                      default = { };
                      description = "Optional local Ollama provider wiring for host-local experimentation.";
                    };
                  };

                  config = {
                    enable = lib.mkDefault true;
                    enableMcpIntegration = lib.mkDefault true;
                    package = lib.mkDefault pkgs.llm-agents.opencode;

                    context = lib.mkDefault ./files/opencode/AGENTS.md;

                    settings = lib.mkDefault {
                      model = premium_model.opencode.model;
                      small_model = small_model.opencode.model;
                      # Let primary agents delegate once, but prevent subagents
                      # from recursively launching more subagents.
                      subagent_depth = 1;

                      permission = {
                        glob = "allow";
                        grep = "allow";
                        list = "allow";
                        lsp = "allow";
                        read = "allow";
                        external_directory = {
                          "/tmp" = "allow";
                          "/nix/**" = "allow";
                          "~/Documents/git/**" = "allow";
                        };
                        edit = {
                          "/nix/**" = "deny";
                          "~/Documents/git/**" = "ask";
                        };
                        "context7_*" = "allow";
                        "websearch" = "allow";
                      };

                      agent = {
                        build = opencodeAgent premium_model;

                        plan = opencodeAgent frontier_model;

                        general = (opencodeAgent standard_model) // {
                          permission = subagentPermission;
                        };

                        explore = (opencodeAgent small_model) // {
                          permission = readOnlyAgentPermission;
                        };

                        title = opencodeAgent small_model;
                        summary = opencodeAgent small_model;
                        compaction = opencodeAgent standard_model;
                      };
                    };
                  };
                }
              )
            ];
          };
          default = { };
          description = "OpenCode home-manager configuration";
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
                    # One agent packaging source: llm-agents also builds omp, so
                    # the binary follows the same overlay/cache path as opencode.
                    package = lib.mkDefault pkgs.llm-agents.omp;

                    # Per-key defaults: a downstream `settings` attrset merges
                    # key-by-key (last one wins per key) instead of replacing
                    # this whole block, so private overlays can override the
                    # model routing without restating shared UI preferences.
                    settings = {
                      # State markers: without these every switch re-runs
                      # onboarding and re-prompts for dev consent.
                      setupVersion = lib.mkDefault 2;
                      dev.autoqaConsent = lib.mkDefault "granted";

                      theme.dark = lib.mkDefault "dark-sakura";
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

                      # Keep agents on structured tools: OMP supplies its own
                      # tool-shadowing defaults; these cover web and GitHub
                      # commands where the native tools preserve more context.
                      bashInterceptor = {
                        enabled = lib.mkDefault true;
                        patterns = lib.mkDefault [
                          {
                            pattern = "^\\s*(curl|wget)\\s+";
                            tool = "read";
                            message = "Use the read tool with the URL instead; it returns clean reader-mode content without a subprocess.";
                          }
                          {
                            pattern = "^\\s*gh\\s+(issue|pr)\\s+(view|list|search|checkout|create|diff)\\b";
                            tool = "github";
                            message = "Use the github tool instead; it wraps gh with structured output and caching.";
                          }
                        ];
                      };

                      # sudo stays available but always asks, including in
                      # yolo sessions.
                      bash.patterns = lib.mkDefault [
                        {
                          match = "sudo *";
                          approval = "prompt";
                        }
                      ];

                      modelRoles = lib.mkDefault {
                        default = premium_model.omp;
                        smol = small_model.omp;
                        slow = frontier_model.omp;
                        vision = standard_model.omp;
                        plan = frontier_model.omp;
                        designer = premium_model.omp;
                        commit = small_model.omp;
                        tiny = small_model.omp;
                        task = standard_model.omp;
                        advisor = frontier_model.omp;
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
          opencode # keep this here, in case opencode managed config disabled
        ];

        programs.mcp = cfg.mcp;
        programs.omp = cfg.omp;
        programs.opencode = lib.mkMerge [
          (builtins.removeAttrs cfg.opencode [
            "skillsSource"
            "ollama"
          ])
          (lib.mkIf cfg.opencode.ollama.enable {
            settings.provider.ollama = {
              npm = "@ai-sdk/openai-compatible";
              name = "ollama";
              options.baseURL = "http://${cfg.opencode.ollama.endpoint}:11434/v1";
              inherit (cfg.opencode.ollama) models;
            };
          })
        ];

        xdg.configFile = lib.mkIf cfg.opencode.enable {
          # Keep the skills tree as an installed directory so local skill files stay
          # available even if the Home Manager option schema changes.
          "opencode/skills" = {
            source = cfg.opencode.skillsSource;
            recursive = true;
          };
        };

        home.sessionVariables = {
          OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";
          OPENCODE_ENABLE_EXA = "true";
        };
      };
    };
}
