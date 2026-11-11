# Rust tooling — from nix-upstream/modules/development/rust.nix
{
  config,
  inputs,
  lib,
  ...
}:
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
      rustupHome = config.home.sessionVariables.RUSTUP_HOME;
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
      isChannelName = name: builtins.match "(stable|beta|nightly|[0-9]+(\\.[0-9]+)*)(-.*)?" name != null;
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
            (`$RUSTUP_HOME/toolchains/<name>`), selectable with `cargo +<name>` or
            `channel = "<name>"` in rust-toolchain.toml. Set
            `home.sessionVariables.RUSTUP_HOME` to an absolute path inside the
            home directory to relocate it (default: `~/.rustup`). The Home
            Manager generation keeps toolchains alive across garbage collection.
            Names must not be rustup channel names or the reserved name `none`;
            other channels and versions are still installed by rustup on demand.
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
            assertion = lib.all (name: name != "none" && !isChannelName name) (lib.attrNames cfg.toolchains);
            message = "aw1cks.rust.toolchains: names must not be rustup channel names (stable, beta, nightly, versions) or the reserved name 'none'.";
          }
          {
            assertion = cfg.defaultToolchain == null || cfg.toolchains ? ${cfg.defaultToolchain};
            message = "aw1cks.rust.defaultToolchain must name an entry of aw1cks.rust.toolchains.";
          }
        ];

        # `programs.cargo` is not available yet on the pinned Home Manager
        # release stream used by this repo, so keep managing Cargo config
        # manually until that lands here.
        home.sessionVariables = {
          CARGO_HOME = "${config.xdg.dataHome}/cargo";
          RUSTUP_HOME = lib.mkDefault "${config.home.homeDirectory}/.rustup";
        };

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

        home.file = lib.mapAttrs' (
          name: toolchain: lib.nameValuePair "${rustupHome}/toolchains/${name}" { source = toolchain; }
        ) cfg.toolchains;

        home.activation.rustupDefaultToolchain = lib.mkIf (cfg.defaultToolchain != null) (
          lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            if ! RUSTUP_HOME=${lib.escapeShellArg rustupHome} ${toolchains.rustup}/bin/rustup default >/dev/null 2>&1; then
              RUSTUP_HOME=${lib.escapeShellArg rustupHome} run ${toolchains.rustup}/bin/rustup default ${lib.escapeShellArg cfg.defaultToolchain}
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

  perSystem =
    { pkgs, ... }:
    {
      checks.rust-toolchains = import ./_rust-toolchains-check.nix {
        inherit inputs lib pkgs;
        rustModule = config.aw1cks.modules.home.rust;
      };
    };
}
