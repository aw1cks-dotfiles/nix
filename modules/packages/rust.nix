# Rust tooling — from nix-upstream/modules/development/rust.nix
{ ... }:
{
  flake.modules.home.rust =
    { pkgs, ... }:
    {
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
