# AI coding tools — from nix-upstream/modules/development/ai.nix
{ ... }:
{
  flake.modules.home.ai =
    { pkgs, ... }:
    {
      home.packages = with pkgs.llm-agents; [
        claude-code
        codex
        gemini-cli
        opencode
      ];
    };
}
