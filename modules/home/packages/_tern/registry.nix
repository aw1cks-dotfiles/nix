{ lib, pkgs, ... }:
let
  sources = lib.mapAttrs (_: pin: pkgs.fetchFromGitHub pin) (import ./plugin-sources.nix);
  projectsBackend = pkgs.rustPlatform.buildRustPackage {
    pname = "tern-projects";
    version = "0.2.12";
    src = sources.tern-projects;
    cargoRoot = "indexer";
    buildAndTestSubdir = "indexer";
    cargoHash = "sha256-QUg3SS8risD2cZkQEI9hobsHaX3zCBrMH78Jf+UoIyI=";
    doCheck = false;
    meta = {
      description = "Local project and agent transcript indexer for Tern Projects";
      homepage = "https://github.com/thegeneralist01/tern-projects";
      license = lib.licenses.mit;
      mainProgram = "tern-projects";
    };
  };
  projects = pkgs.runCommand "tern-projects-plugin-0.2.12" { } ''
    mkdir -p "$out"
    cp -R ${sources.tern-projects}/. "$out/"
    chmod -R u+w "$out"
    substitute ${./projects-backend.luau} "$out/lib/backend.luau" \
      --subst-var-by backend ${lib.getExe projectsBackend}
  '';
  kata = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
    pname = "tern-kata";
    version = "0.11.0";
    src = sources.tern-kata;
    vendorHash = "sha256-3g30MsV6/FXRvHWHj6XbcH8mYTLmcQb7K7hkiuwdQlo=";
    subPackages = [ "cmd/tern-kata" ];
    env.CGO_ENABLED = 0;
    ldflags = [
      "-s"
      "-w"
      "-X main.version=v0.11.0"
    ];
    doCheck = false;
    meta = {
      description = "Kata issue CLI and worker for the native Tern plugin";
      homepage = "https://github.com/Dangerboi/tern-kata";
      license = lib.licenses.mit;
      mainProgram = "tern-kata";
    };
  };
in
{
  modules.tern.plugins = {
    tern-projects = {
      source = lib.mkDefault projects;
      runtimePackages = [ projectsBackend ];
    };
    tern-kata = {
      source = lib.mkDefault sources.tern-kata;
      runtimePackages = [ kata ];
    };
    tern-kube = {
      source = lib.mkDefault sources.tern-kube;
      runtimePackages = [ pkgs.kubectl ];
    };
    tern-grafana.source = lib.mkDefault sources.tern-grafana;
  };
}
