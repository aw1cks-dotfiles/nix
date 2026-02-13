{ lib, ... }:
{
  flake-file.inputs.claude-code = {
    url = lib.mkDefault "github:sadjow/claude-code-nix";
  };
}
