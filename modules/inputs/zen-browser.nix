{ lib, ... }:
{
  flake-file.inputs.zen-browser = {
    # Pinned to commit with updated twilight hashes (Feb 23, 2026)
    # See: https://github.com/0xc000022070/zen-browser-flake/commit/9ee8fb00d7333b1b2b65d686b160da19a57d5730
    url = lib.mkDefault "github:0xc000022070/zen-browser-flake/9ee8fb00d7333b1b2b65d686b160da19a57d5730";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };
}
