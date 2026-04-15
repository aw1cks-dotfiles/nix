{ lib, ... }:
{
  flake-file.inputs = {
    agenix = {
      url = lib.mkDefault "github:ryantm/agenix";
      inputs = {
        home-manager.follows = lib.mkDefault "home-manager";
        nixpkgs.follows = lib.mkDefault "nixpkgs";
      };
    };

    disko = {
      url = lib.mkDefault "github:nix-community/disko";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    home-manager = {
      url = lib.mkDefault "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    lazyvim-nix = {
      # Temporary fork to work around some tree-sitter issues. See pfassina/lazyvim-nix#72
      url = lib.mkDefault "github:aw1cks-forks/lazyvim-nix/fix/ts_parser_metadata_from_nvim_treesitter";
      # url = lib.mkDefault "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    mermaid-rs-renderer = {
      url = lib.mkDefault "github:1jehuang/mermaid-rs-renderer";
      flake = false;
    };

    nix-index-database = {
      url = lib.mkDefault "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    nix-darwin = {
      url = lib.mkDefault "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    nixos-hardware = {
      url = lib.mkDefault "github:NixOS/nixos-hardware";
    };

    nixpkgs-unstable = {
      url = lib.mkDefault "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    stylix = {
      url = lib.mkDefault "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    llm-agents = {
      url = lib.mkDefault "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
    };

    zen-browser = {
      url = lib.mkDefault "github:0xc000022070/zen-browser-flake";
      inputs = {
        home-manager.follows = lib.mkDefault "home-manager";
        nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
      };
    };

    treefmt-nix = {
      url = lib.mkDefault "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };

    wezterm = {
      url = lib.mkDefault "github:wezterm/wezterm?dir=nix";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
    };

    lix = {
      url = lib.mkDefault "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };

    lix-module = {
      url = lib.mkDefault "https://git.lix.systems/api/v1/repos/lix-project/nixos-module/archive/5e56f5a973e24292b125dca9e9d506b0a91d6903.tar.gz?rev=5e56f5a973e24292b125dca9e9d506b0a91d6903";
      inputs.lix.follows = lib.mkDefault "lix";
      inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
    };
  };
}
