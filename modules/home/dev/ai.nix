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
      readOnlyAgentPermission = {
        edit = "deny";
      };
    in
    {
      options.modules.ai = {
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

                    rules = lib.mkDefault ./files/opencode/AGENTS.md;

                    settings = lib.mkDefault {
                      # Keep agent selection in `agent` and shared reasoning defaults in
                      # `provider.openrouter.models` so model-specific tuning stays deduplicated.
                      model = "openrouter/openai/gpt-5.4-mini";
                      small_model = "openrouter/google/gemini-2.5-flash-lite";

                      provider.openrouter.models = {
                        "anthropic/claude-opus-4.6".options.reasoning = {
                          max_tokens = 4000;
                          exclude = true;
                        };

                        "anthropic/claude-sonnet-4.6".options.reasoning = {
                          max_tokens = 2000;
                          exclude = true;
                        };

                        "openai/gpt-5.4-mini".options.reasoning = {
                          effort = "low";
                          exclude = true;
                        };

                        "x-ai/grok-4.1-fast".options.reasoning = {
                          enabled = false;
                        };

                        "z-ai/glm-5.1".options.reasoning = {
                          effort = "low";
                          exclude = true;
                        };
                      };

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
                        plan = {
                          description = "Task classification and decomposition";
                          mode = "subagent";
                          model = "openrouter/google/gemini-2.5-flash-lite";
                          permission = readOnlyAgentPermission;
                        };

                        summary-helper = {
                          description = "Logs, docs, and large text compression";
                          mode = "subagent";
                          model = "openrouter/google/gemini-2.5-flash-lite";
                          permission = readOnlyAgentPermission;
                        };

                        explore = {
                          description = "A fast, read-only agent for narrowing codebase scope";
                          mode = "subagent";
                          model = "openrouter/z-ai/glm-5.1";
                          permission = readOnlyAgentPermission;
                        };

                        fast-helper = {
                          description = "Cheap fast helper for broad utility work";
                          mode = "subagent";
                          model = "openrouter/x-ai/grok-4.1-fast";
                        };

                        general = {
                          description = "General-purpose coding and execution agent";
                          mode = "subagent";
                          model = "openrouter/openai/gpt-5.4-mini";
                        };

                        deep-review = {
                          description = "Long-context reviewer for difficult synthesis and judgment";
                          mode = "subagent";
                          model = "openrouter/anthropic/claude-sonnet-4.6";
                          permission = readOnlyAgentPermission;
                        };

                        premium-review = {
                          description = "Premium reviewer for high-risk judgment calls";
                          mode = "subagent";
                          model = "openrouter/anthropic/claude-opus-4.6";
                          permission = readOnlyAgentPermission;
                        };

                        experimental-open = {
                          description = "Experimental cheap open-model helper lane";
                          mode = "subagent";
                          model = "openrouter/google/gemma-4-26b-a4b-it";
                        };
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
      };

      config = {
        home.packages = with pkgs.llm-agents; [
          claude-code
          opencode # keep this here, in case opencode managed config disabled
        ];

        programs.mcp = cfg.mcp;
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
          # Home Manager release-25.11 does not expose `programs.opencode.skills` yet,
          # so install the skills tree into XDG config until that option lands there.
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
