# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    crds-catalog = {
      url = "github:datreeio/CRDs-catalog";
      flake = false;
    };
    dendritic-lib = {
      url = "github:aw1cks-dotfiles/nix";
      inputs = {
        agenix.follows = "agenix";
        apple-fonts.follows = "apple-fonts";
        crds-catalog.follows = "crds-catalog";
        disko.follows = "disko";
        flake-file.follows = "flake-file";
        flake-parts.follows = "flake-parts";
        home-manager.follows = "home-manager";
        import-tree.follows = "import-tree";
        intel-performance-skills.follows = "intel-performance-skills";
        lazyvim-nix.follows = "lazyvim-nix";
        llm-agents.follows = "llm-agents";
        low-level-dev-skills.follows = "low-level-dev-skills";
        lucidglyph.follows = "lucidglyph";
        mermaid-rs-renderer.follows = "mermaid-rs-renderer";
        niri.follows = "niri";
        nix-cachyos-kernel.follows = "nix-cachyos-kernel";
        nix-darwin.follows = "nix-darwin";
        nix-index-database.follows = "nix-index-database";
        nixos-hardware.follows = "nixos-hardware";
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        oh-my-pi.follows = "oh-my-pi";
        rewrite-rs-skills.follows = "rewrite-rs-skills";
        stylix.follows = "stylix";
        trailofbits-skills.follows = "trailofbits-skills";
        treefmt-nix.follows = "treefmt-nix";
        zen-browser.follows = "zen-browser";
      };
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-file.url = "github:denful/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    intel-performance-skills = {
      url = "github:intel/intel-performance-skills/3e33aecabb956ec48526b3f842f4f70ae96d98ff";
      flake = false;
    };
    lazyvim-nix = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    low-level-dev-skills = {
      url = "github:mohitmishra786/low-level-dev-skills/bdc58472fa9f309ed1b3f7d985a0d8e9bd8f4608";
      flake = false;
    };
    lucidglyph = {
      url = "github:maximilionus/lucidglyph";
      flake = false;
    };
    mermaid-rs-renderer = {
      url = "github:1jehuang/mermaid-rs-renderer/v0.3.1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    niri = {
      url = "github:epireyn/niri-flake";
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
    oh-my-pi = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    rewrite-rs-skills = {
      url = "github:rewrite-rs/skills/ae0fd62485d071437ae5e6c4036c986b0dd122a0";
      flake = false;
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    trailofbits-skills = {
      url = "github:trailofbits/skills/e4dd0bb5b15535f7c5a0834187dffba6ac37e4ff";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
