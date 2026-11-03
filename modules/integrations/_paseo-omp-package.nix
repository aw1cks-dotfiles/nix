{ pkgs }:
let
  inherit (pkgs) lib;
  # The published production-only shrinkwrap is vendored verbatim. importNpmLock
  # fetches every dependency by its recorded integrity hash, without an aggregate
  # cache hash or dependency resolution during the sandboxed installation.
  packageLock = lib.importJSON ./_paseo-omp-npm-shrinkwrap.json;
  package = packageLock.packages."" // {
    # importNpmLock uses this name for its derivation; Nix names cannot contain
    # the slash in the npm scope. The installed plugin retains its real name.
    name = "paseo-omp";
    type = "module";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "paseo-omp";
  version = "5.2.3";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@omercnet/paseo-omp/-/paseo-omp-5.2.3.tgz";
    hash = "sha512-rbgwh1f1OFwfGRLl2IATuiAj0ToSrGVHT3SMdXqhwDM7cSD2q65WLLAwoT81Q/WTe78mqZUv5D1TdT9B2Umqrg==";
  };

  npmDeps = pkgs.importNpmLock { inherit package packageLock; };
  nativeBuildInputs = [
    pkgs.nodejs_24
    pkgs.jq
    pkgs.importNpmLock.npmConfigHook
  ];
  strictDeps = true;
  npmInstallFlags = [
    "--omit=dev"
    "--workspaces=false"
  ];
  npmFlags = [
    "--ignore-scripts"
    "--offline"
  ];

  postPatch = ''
    # The published shrinkwrap intentionally excludes development dependencies.
    # Match its manifest before the hook's offline installation, just as upstream
    # preparation does, and avoid npm preferring an unpatched shrinkwrap over
    # importNpmLock's store-backed package-lock.json.
    jq 'del(.devDependencies, .overrides)' package.json > package.json.tmp
    mv package.json.tmp package.json
    mv npm-shrinkwrap.json package-lock.json
  '';

  # Paseo compiles both TypeScript entrypoints with its own plugin compiler. Keep
  # their complete source trees and the installed production dependencies rather
  # than shipping an incomplete source copy or a separately compiled server.
  dontBuild = true;
  installPhase = ''
    runHook preInstall

    pluginRoot="$out/share/paseo-omp"
    mkdir -p "$pluginRoot"
    cp -R . "$pluginRoot/"
    mv "$pluginRoot/package-lock.json" "$pluginRoot/npm-shrinkwrap.json"

    # Only remove upstream's runtime npm preparation after Nix has installed the
    # dependencies. Local directory registration must not download or mutate the
    # immutable store source when Paseo prepares and compiles this plugin.
    test -d "$pluginRoot/node_modules/@getpaseo/protocol"
    test -d "$pluginRoot/node_modules/@modelcontextprotocol/sdk"
    test -d "$pluginRoot/node_modules/yaml"
    jq 'del(.build)' "$pluginRoot/paseo-plugin.json" > "$pluginRoot/paseo-plugin.json.tmp"
    mv "$pluginRoot/paseo-plugin.json.tmp" "$pluginRoot/paseo-plugin.json"
    rm "$pluginRoot/scripts/prepare-dependencies.mjs"
    rmdir "$pluginRoot/scripts"

    runHook postInstall
  '';

  passthru = {
    pluginId = "paseo-omp";
    providerId = "omp-plugin";
    pluginDirectory = "share/paseo-omp";
  };

  meta = {
    description = "Pinned OMP Plugin source and offline dependencies for Paseo";
    homepage = "https://github.com/omercnet/paseo-plugins/tree/main/paseo-omp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
