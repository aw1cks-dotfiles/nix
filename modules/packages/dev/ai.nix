# AI coding tools — from nix-upstream/modules/development/ai.nix
{ ... }:
{
  flake.modules.home.ai =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.modules.ai;
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

                  options.skillsSource = lib.mkOption {
                    type = lib.types.path;
                    default = ./files/opencode/skills;
                    description = "Bundled OpenCode skills directory exposed as a stable downstream contract.";
                  };

                  config = {
                    enable = lib.mkDefault true;
                    enableMcpIntegration = lib.mkDefault true;
                    package = lib.mkDefault pkgs.llm-agents.opencode;

                    rules = lib.mkDefault ./files/opencode/AGENTS.md;

                    settings = lib.mkDefault {
                      plugin = [ "opencode-gemini-auth@latest" ];

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
        programs.opencode = builtins.removeAttrs cfg.opencode [ "skillsSource" ];

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
