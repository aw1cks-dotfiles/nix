# Rust toolchain selection shared by the rust, language-server and editor
# modules. rustup stays the dispatcher (rust-toolchain.toml, `cargo +x`); the
# Nix-built toolchains are linked into it as custom toolchains by ./rust.nix.
{
  config,
  inputs,
  lib,
  pkgs,
}:
let
  rustBin = inputs.rust-overlay.lib.mkRustBin { } pkgs;

  # `minimal` plus explicit extensions: the `default` profile adds rust-docs,
  # which is large and only serves `rustup doc`. rust-src lets rust-analyzer
  # resolve std/core.
  stable = rustBin.stable.latest.minimal.override {
    extensions = [
      "clippy"
      "rustfmt"
      "rust-src"
      "rust-analyzer"
    ];
  };
  nightly = rustBin.selectLatestNightlyWith (
    toolchain:
    toolchain.minimal.override {
      extensions = [
        "clippy"
        "rustfmt"
        "rust-src"
      ];
    }
  );

  # nixpkgs patches every toolchain rustup downloads to point at fixed store
  # paths (ELF interpreter, RUNPATH, a gcc-ld/ld.lld wrapper). Nothing roots
  # those paths, so the toolchains break after a rustup upgrade plus GC
  # (NixOS/nixpkgs#473661). Generic Linux runs upstream binaries natively, so
  # use rustup as released there; NixOS still needs the patch.
  rustup =
    if pkgs.stdenv.hostPlatform.isLinux && (config.targets.genericLinux.enable or false) then
      pkgs.rustup.overrideAttrs (old: {
        patches = [ ];
        # The suite already runs against the patched nixpkgs build; removing
        # the patch only drops code.
        doCheck = false;
        # The LD_LIBRARY_PATH=zlib wrapper serves patched toolchains only and
        # otherwise leaks a Nix library into every cargo/rustc child process.
        postInstall = old.postInstall + ''
          mv -f $out/bin/.rustup-wrapped $out/bin/rustup
        '';
      })
    else
      pkgs.rustup;
in
{
  inherit nightly rustup stable;

  # Preserve explicit sources and the selected compiler's rust-src. Plain
  # nixpkgs compilers omit sources, so retain nixpkgs' analyzer fallback there.
  rust-analyzer = pkgs.writeShellScriptBin "rust-analyzer" ''
    if [ -z "''${RUST_SRC_PATH+x}" ]; then
      sysroot="$("''${RUSTC:-rustc}" --print sysroot 2>/dev/null)" || sysroot=
      if [ -z "$sysroot" ] || [ ! -d "$sysroot/lib/rustlib/src/rust/library" ]; then
        export RUST_SRC_PATH=${lib.escapeShellArg (toString pkgs.rustPlatform.rustLibSrc)}
      fi
    fi
    exec ${stable}/bin/rust-analyzer "$@"
  '';

  # Editor wrapper PATH fallback. With the rust module, rustup's proxies keep
  # rust-toolchain.toml authoritative even when the editor is launched without
  # the user profile on PATH; without it there is no rustup default, so supply
  # the Nix stable toolchain directly.
  editorPackages = if lib.hasAttrByPath [ "aw1cks" "rust" ] config then [ rustup ] else [ stable ];
}
