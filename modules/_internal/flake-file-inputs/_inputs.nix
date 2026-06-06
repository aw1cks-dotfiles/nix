# Shared transitive inputs for downstream consumers of dendritic-lib.
#
# Plain Nix data file (not a flake-parts module) so siblings can import it for
# attribute-name introspection (e.g. auto-generated follows for the
# dendritic-lib input itself). See ./default.nix and
# ../downstream-dendritic-input.nix.
{ lib }:
{
  agenix = {
    url = lib.mkDefault "github:ryantm/agenix";
    inputs = {
      home-manager.follows = lib.mkDefault "home-manager";
      nixpkgs.follows = lib.mkDefault "nixpkgs";
    };
  };

  disko = {
    url = lib.mkDefault "github:nix-community/disko/5ae05d98d2bebc0a9521c9fc89bd2e5cffa05926";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager/release-26.05";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  lazyvim-nix = {
    url = lib.mkDefault "github:pfassina/lazyvim-nix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  niri = {
    url = lib.mkDefault "github:sodiboo/niri-flake";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };

  mermaid-rs-renderer = {
    url = lib.mkDefault "github:1jehuang/mermaid-rs-renderer/v0.2.1";
    flake = false;
  };

  nix-index-database = {
    url = lib.mkDefault "github:nix-community/nix-index-database";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  nix-darwin = {
    url = lib.mkDefault "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  nixos-hardware = {
    url = lib.mkDefault "github:NixOS/nixos-hardware";
  };

  nixpkgs-unstable = {
    url = lib.mkDefault "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  stylix = {
    url = lib.mkDefault "github:nix-community/stylix/release-26.05";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  llm-agents = {
    url = lib.mkDefault "github:numtide/llm-agents.nix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };

  apple-fonts = {
    url = lib.mkDefault "github:Lyndeno/apple-fonts.nix";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs-unstable";
  };

  nix-cachyos-kernel = {
    # Prebuilt CachyOS kernels (Clang+ThinLTO+BORE+CachyOS sauce) for NixOS.
    # Successor to the now-archived chaotic-nyx (archived 2025-12-08).
    # The "release" branch is bumped only after the maintainer's NixOS
    # build matrix passes, including nvidia-open and ZFS configs.
    #
    # IMPORTANT: do NOT override the upstream nixpkgs follow. The repo
    # ships its own pinned nixpkgs to keep patch sets matched to the
    # kernel version; mismatched nixpkgs => build failures.
    #
    # Binary cache: https://attic.xuyh0120.win/lantian (xddxdd's Hydra CI).
    # Key added to modules/shared/nix-settings.nix. The `pinned` overlay was
    # previously needed for cache hits but since 2026-03-01 the flake pins its
    # own kernel source independent of nixpkgs, so the `default` overlay is
    # equally safe. We continue using legacyPackages directly (equivalent to
    # `default` overlay) in the cachyos-kernel module.
    url = lib.mkDefault "github:xddxdd/nix-cachyos-kernel/release";
    flake = true;
  };

  lucidglyph = {
    url = lib.mkDefault "github:maximilionus/lucidglyph";
    flake = false;
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
    # see:
    # https://github.com/wezterm/wezterm/pull/7463
    # https://github.com/wezterm/wezterm/pull/7726
    url = lib.mkDefault "github:aw1cks-forks/wezterm/fix/nix-rust-overlay-update?dir=nix";
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
}
