# Rust tooling — from nix-upstream/modules/development/rust.nix
{ dl, ... }:
{
  dl.dev-rust.homeManager =
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
