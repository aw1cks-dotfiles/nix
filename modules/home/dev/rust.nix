# Rust tooling — from nix-upstream/modules/development/rust.nix
{ ... }:
{
  aw1cks.modules.home.rust =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cargoToml = pkgs.formats.toml { };
    in
    {
      options.aw1cks.rust.cargo.settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional Cargo configuration merged into the generated config.toml.";
      };

      config = {
        # `programs.cargo` is not available yet on the pinned Home Manager
        # release stream used by this repo, so keep managing Cargo config
        # manually until that lands here.
        home.sessionVariables.CARGO_HOME = "${config.xdg.dataHome}/cargo";

        xdg.configFile."cargo/config.toml".source = cargoToml.generate "cargo-config.toml" (
          lib.recursiveUpdate {
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
          } config.aw1cks.rust.cargo.settings
        );

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
    };
}
