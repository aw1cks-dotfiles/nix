{
  inputs,
  lib,
  pkgs,
  rustModule,
}:
let
  toolchains = import ./_rust-toolchains.nix {
    inherit inputs lib pkgs;
    config = { };
  };
  mkHome =
    name: extra:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        rustModule
        {
          home.username = "rust-toolchains-check";
          # Nix substitutes the check's writable output in its activation snippets.
          home.homeDirectory = "${builtins.placeholder "out"}/${name}";
          home.stateVersion = "25.05";
          home.packages = lib.mkForce [ ];
          aw1cks.rust.toolchains = lib.mkForce {
            nix-stable = toolchains.stable;
            nix-other = toolchains.stable;
          };
        }
        extra
      ];
    };
  defaultHome = mkHome "default-home" { };
  customHome = mkHome "custom-home" (
    { config, ... }: {
      home.sessionVariables.RUSTUP_HOME = "${config.home.homeDirectory}/rustup custom";
    }
  );
  invalidHome = mkHome "invalid-home" {
    aw1cks.rust.toolchains = lib.mkForce { none = toolchains.stable; };
    aw1cks.rust.defaultToolchain = "none";
  };
  checkHome = home: ''
    (
      export HOME=${lib.escapeShellArg home.config.home.homeDirectory}
      mkdir -p "$HOME"
      cp -R --no-preserve=mode ${home.config.home-files}/. "$HOME"
      managedRustupHome=${lib.escapeShellArg home.config.home.sessionVariables.RUSTUP_HOME}
      export RUSTUP_HOME="$TMPDIR/inherited-rustup"
      run() { "$@"; }

      ${home.config.home.activation.rustupDefaultToolchain.data}
      expectDefault "$managedRustupHome" nix-stable
      test ! -e "$RUSTUP_HOME/settings.toml"

      RUSTUP_HOME="$managedRustupHome" ${toolchains.rustup}/bin/rustup default nix-other
      ${home.config.home.activation.rustupDefaultToolchain.data}
      expectDefault "$managedRustupHome" nix-other

      rm "$managedRustupHome/settings.toml"
      run() { :; }
      ${home.config.home.activation.rustupDefaultToolchain.data}
      if RUSTUP_HOME="$managedRustupHome" ${toolchains.rustup}/bin/rustup default; then
        echo "dry-run activation changed the Rustup default" >&2
        exit 1
      fi
    )
  '';
in
assert builtins.seq defaultHome.activationPackage.drvPath true;
assert builtins.seq customHome.activationPackage.drvPath true;
assert !(builtins.tryEval invalidHome.activationPackage.drvPath).success;
pkgs.runCommand "rust-toolchains-check"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    analyzer = "${toolchains.rust-analyzer}/bin/rust-analyzer";
    compiler = "${pkgs.rustc}/bin/rustc";
    cargo = "${pkgs.cargo}/bin/cargo";
    sourcedCompiler = "${toolchains.stable}/bin/rustc";
    fallbackSources = pkgs.rustPlatform.rustLibSrc;
    toolchainSources = "${toolchains.stable}/lib/rustlib/src/rust/library";
  }
  ''
    expectDefault() {
      python3 - "$1/settings.toml" "$2" <<'PY'
    import sys, tomllib
    with open(sys.argv[1], "rb") as settings:
        assert tomllib.load(settings)["default_toolchain"] == sys.argv[2]
    PY
    }
    ${checkHome defaultHome}
    ${checkHome customHome}
    python3 ${./_rust-analyzer-check.py}
    rm -r "$out/default-home" "$out/custom-home"
    touch "$out/passed"
  ''
