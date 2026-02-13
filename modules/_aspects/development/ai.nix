# AI coding tools — from nix-upstream/modules/development/ai.nix
{ dl, ... }:
{
  dl.dev-ai.homeManager =
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
