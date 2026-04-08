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
          type = lib.types.anything;
          description = "OpenCode home-manager configuration";

          default = {
            enable = true;
            enableMcpIntegration = true;
            package = pkgs.llm-agents.opencode;

            rules = ./files/opencode/AGENTS.md;

            settings = {
              plugin = [ "opencode-gemini-auth@latest" ];

              permission = {
                glob = "allow";
                grep = "allow";
                list = "allow";
                lsp = "allow";
                read = "allow";
              };
            };
          };
        };
      };

      config = {
        home.packages = with pkgs.llm-agents; [
          claude-code
          opencode # keep this here, in case opencode managed config disabled
        ];

        programs.mcp = cfg.mcp;
        programs.opencode = cfg.opencode;

        xdg.configFile = lib.mkIf cfg.opencode.enable {
          # Home Manager release-25.11 does not expose `programs.opencode.skills` yet,
          # so install the skills tree into XDG config until that option lands there.
          "opencode/skills" = {
            source = ./files/opencode/skills;
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
