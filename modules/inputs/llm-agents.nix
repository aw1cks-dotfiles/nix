{ lib, ... }:
{
  flake-file.inputs.llm-agents = {
    url = lib.mkDefault "github:numtide/llm-agents.nix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };
}
