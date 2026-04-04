# Rust tooling — from nix-upstream/modules/development/rust.nix
{ pkgs, ... }:
{
  flake.modules.home.rust =
    { config, pkgs, ... }:
    let
      cargoToml = pkgs.formats.toml { };
    in
    {
      # `programs.cargo` is not available yet on the pinned Home Manager
      # release stream used by this repo, so keep managing Cargo config
      # manually until that lands here.
      home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";

      xdg.dataFile."cargo/config.toml".source = cargoToml.generate "cargo-config.toml" {
        alias = {
          b = "build";
          c = "check";
          t = "test";
          r = "run";
          rr = "run --release";
        };
        cargo-new.vcs = "git";
        # TODO: consider `${config.xdg.dataHome}/cargo`?
        install.root = "${config.home.homeDirectory}/.local";

        profile.optimised = {
          inherits = "release";
          debug = false;
          strip = true;
          lto = true;
        };
      };

      home.packages = with pkgs; [
        cargo-bloat
        cargo-edit
        cargo-feature
        cargo-semver-checks
        cargo-outdated
        cargo-sort
        cargo-udeps
        evcxr
        rustup
        sqlx-cli
      ];
    };
}
