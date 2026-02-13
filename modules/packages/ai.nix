# AI coding tools — from nix-upstream/modules/development/ai.nix
{ ... }:
{
  flake.modules.home.ai =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        claude-code
        unstable.codex
        unstable.gemini-cli
        unstable.opencode
      ];
    };
}
