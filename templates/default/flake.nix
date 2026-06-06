# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "Private Nix configuration — hosts, secrets, and site-specific settings";

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.dendritic-lib.flakeModules.default
        (inputs.import-tree ./modules)
        ./hosts
      ];
    };

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    dendritic-lib = {
      url = "github:aw1cks-dotfiles/nix";
      inputs = {
        agenix.follows = "agenix";
        apple-fonts.follows = "apple-fonts";
        disko.follows = "disko";
        flake-file.follows = "flake-file";
        flake-parts.follows = "flake-parts";
        home-manager.follows = "home-manager";
        import-tree.follows = "import-tree";
        lazyvim-nix.follows = "lazyvim-nix";
        lix.follows = "lix";
        lix-module.follows = "lix-module";
        llm-agents.follows = "llm-agents";
        lucidglyph.follows = "lucidglyph";
        mermaid-rs-renderer.follows = "mermaid-rs-renderer";
        niri.follows = "niri";
        nix-cachyos-kernel.follows = "nix-cachyos-kernel";
        nix-darwin.follows = "nix-darwin";
        nix-index-database.follows = "nix-index-database";
        nixos-hardware.follows = "nixos-hardware";
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        stylix.follows = "stylix";
        treefmt-nix.follows = "treefmt-nix";
        wezterm.follows = "wezterm";
        zen-browser.follows = "zen-browser";
      };
    };
    disko = {
      url = "github:nix-community/disko/5ae05d98d2bebc0a9521c9fc89bd2e5cffa05926";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    lazyvim-nix = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    lix-module = {
      url = "https://git.lix.systems/api/v1/repos/lix-project/nixos-module/archive/5e56f5a973e24292b125dca9e9d506b0a91d6903.tar.gz?rev=5e56f5a973e24292b125dca9e9d506b0a91d6903";
      inputs = {
        lix.follows = "lix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    lucidglyph = {
      url = "github:maximilionus/lucidglyph";
      flake = false;
    };
    mermaid-rs-renderer = {
      url = "github:1jehuang/mermaid-rs-renderer/v0.2.1";
      flake = false;
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm = {
      url = "github:aw1cks-forks/fix/nix-rust-overlay-update?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs-unstable";
      };
    };
  };
}
