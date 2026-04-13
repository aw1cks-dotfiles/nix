{
  inputs,
  lib,
}:
pkgs:
pkgs.rustPlatform.buildRustPackage rec {
  pname = "mmdr";
  version = builtins.substring 0 7 inputs.mermaid-rs-renderer.rev;

  src = inputs.mermaid-rs-renderer;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
  };

  meta = {
    description = "Fast native Rust Mermaid renderer";
    homepage = "https://github.com/1jehuang/mermaid-rs-renderer";
    license = lib.licenses.mit;
    mainProgram = "mmdr";
  };
}
