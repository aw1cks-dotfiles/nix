# Rust tooling — from nix-upstream/modules/development/rust.nix
{ inputs, ... }:
{
  aw1cks.modules.home.rust =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.aw1cks.rust;
      cargoToml = pkgs.formats.toml { };
      toolchains = import ./_rust-toolchains.nix {
        inherit
          config
          inputs
          lib
          pkgs
          ;
      };
      # rustup treats these names as release channels and would try to update
      # a linked toolchain that used one.
      isChannelName =
        name: builtins.match "(stable|beta|nightly|[0-9]+(\\.[0-9]+)*)(-.*)?" name != null;
    in
    {
      options.aw1cks.rust = {
        cargo.settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Additional Cargo configuration merged into the generated config.toml.";
        };

        toolchains = lib.mkOption {
          type = lib.types.attrsOf lib.types.package;
          default = {
            nix-stable = toolchains.stable;
            nix-nightly = toolchains.nightly;
          };
          defaultText = lib.literalMD "rust-overlay's latest stable and latest complete nightly, each with clippy, rustfmt and rust-src";
          description = ''
            Nix-built toolchains linked into rustup as custom toolchains
            (`~/.rustup/toolchains/<name>`), selectable with `cargo +<name>` or
            `channel = "<name>"` in rust-toolchain.toml. The Home Manager
            generation keeps them alive across garbage collection. Names must
            not be rustup channel names; other channels and versions are still
            installed by rustup on demand.
          '';
        };

        defaultToolchain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "nix-stable";
          description = ''
            Entry of `toolchains` made rustup's default during activation when
            no default is configured. An existing default is never replaced.
          '';
        };
      };

      config = {
        assertions = [
          {
            assertion = !lib.any isChannelName (lib.attrNames cfg.toolchains);
            message = "aw1cks.rust.toolchains: names must not be rustup channel names (stable, beta, nightly, versions).";
          }
          {
            assertion = cfg.defaultToolchain == null || cfg.toolchains ? ${cfg.defaultToolchain};
            message = "aw1cks.rust.defaultToolchain must name an entry of aw1cks.rust.toolchains.";
          }
        ];

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
          } cfg.cargo.settings
        );

        # rustup's default RUSTUP_HOME; this module does not relocate it.
        home.file = lib.mapAttrs' (
          name: toolchain: lib.nameValuePair ".rustup/toolchains/${name}" { source = toolchain; }
        ) cfg.toolchains;

        home.activation.rustupDefaultToolchain = lib.mkIf (cfg.defaultToolchain != null) (
          lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            if ! ${toolchains.rustup}/bin/rustup default >/dev/null 2>&1; then
              run ${toolchains.rustup}/bin/rustup default ${lib.escapeShellArg cfg.defaultToolchain}
            fi
          ''
        );

        home.packages = with pkgs; [
          bacon
          cargo-bloat
          cargo-edit
          cargo-feature
          cargo-semver-checks
          cargo-outdated
          cargo-sort
          cargo-udeps
          evcxr
          toolchains.rustup
          sqlx-cli
        ];
      };
    };
}
