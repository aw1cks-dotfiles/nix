{ pkgs, ompInput }:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;
  # Match upstream's Intel Darwin fallback; current unstable no longer supports it.
  packagePkgs =
    if system == "x86_64-darwin" then
      ompInput.inputs.nixpkgs-darwin-x64.legacyPackages.${system}
    else
      pkgs;
  upstream = ompInput.packages.${system}.omp;
  # Reading these attributes does not build omp or its Rust/native components.
  bun = lib.findFirst (
    input: lib.getName input == "bun"
  ) (throw "omp-collab: upstream omp does not expose its pinned Bun") upstream.nativeBuildInputs;
  bunHook = lib.findFirst (
    input: lib.getName input == "bun2nix-hook"
  ) (throw "omp-collab: upstream omp does not expose its bun2nix hook") upstream.nativeBuildInputs;
in
packagePkgs.stdenvNoCC.mkDerivation {
  pname = "omp-collab";
  inherit (upstream) version bunDeps;
  src = ompInput.outPath;

  # This is upstream's development relay, not its hosted Go server:
  # https://github.com/can1357/oh-my-pi/pull/8166
  # Track supported self-hosted packaging before replacing this local build:
  # https://github.com/can1357/oh-my-pi/issues/3408

  patches = [
    ./_omp-collab-loopback.patch
    ./_omp-collab-no-analytics.patch
  ];
  nativeBuildInputs = [
    bun
    bunHook
    packagePkgs.makeWrapper
  ];
  strictDeps = true;
  # The upstream hook resolves catalog references and installs exclusively from
  # the pinned bunDeps cache. Copying works in sandboxed Darwin and Linux builds.
  bunInstallFlags = [
    "--linker=isolated"
    "--backend=copyfile"
  ];
  dontConfigure = true;
  dontRunLifecycleScripts = true;
  dontUseBunBuild = true;
  dontUseBunCheck = true;
  dontUseBunInstall = true;

  buildPhase = ''
    runHook preBuild

    bun build packages/collab-web/scripts/local-relay.ts \
      --target=bun --format=esm --outfile=relay.js

    cd packages/collab-web
    # Explicit production mode selects the matching production JSX runtime.
    # NODE_ENV alone is insufficient for Bun's HTML bundler.
    bun build ./index.html --production --outdir=dist --minify \
      --define 'process.env.NODE_ENV="production"' \
      --entry-naming='[hash].[ext]' --chunk-naming='[hash].[ext]' \
      --asset-naming='[hash].[ext]'
    mv dist/*.html dist/index.html
    cp -R public/. dist/
    cd ../..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec" "$out/share/omp-collab"
    install -m644 relay.js "$out/libexec/omp-collab-relay.js"
    cp -R packages/collab-web/dist/. "$out/share/omp-collab/"
    install -Dm644 LICENSE "$out/share/doc/omp-collab/LICENSE"
    # The CLI notices cover the shared collab-web viewer and JavaScript packages.
    # We do not bundle the native addon, so its separate notices are not needed.
    install -Dm644 packages/coding-agent/THIRD-PARTY-NOTICES.txt \
      "$out/share/doc/omp-collab/THIRD-PARTY-NOTICES.txt"

    # Bundled JS needs neither node_modules nor Bun's automatic package install.
    makeWrapper ${lib.getExe bun} "$out/bin/omp-collab-relay" \
      --add-flags "--config=/dev/null --no-install $out/libexec/omp-collab-relay.js"

    cat > "$out/bin/omp-collab-web" <<'EOF'
    #!${packagePkgs.runtimeShell}
    set -eu
    port=7467
    case "$#" in
      0) ;;
      1)
        case "$1" in
          --port=*) port="''${1#--port=}" ;;
          *) echo 'usage: omp-collab-web [--port PORT]' >&2; exit 1 ;;
        esac
        ;;
      2)
        if [ "$1" != --port ]; then
          echo 'usage: omp-collab-web [--port PORT]' >&2
          exit 1
        fi
        port="$2"
        ;;
      *) echo 'usage: omp-collab-web [--port PORT]' >&2; exit 1 ;;
    esac
    case "$port" in
      ""|*[!0-9]*) echo 'omp-collab-web: invalid port' >&2; exit 1 ;;
    esac
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
      echo 'omp-collab-web: invalid port' >&2
      exit 1
    fi
    exec ${lib.getExe packagePkgs.darkhttpd} @assets@ --addr 127.0.0.1 --port "$port" --no-listing
    EOF
    substituteInPlace "$out/bin/omp-collab-web" \
      --replace-fail '@assets@' "$out/share/omp-collab"
    chmod +x "$out/bin/omp-collab-web"

    runHook postInstall
  '';

  meta = {
    description = "Loopback-only OMP collaboration relay and browser client";
    homepage = "https://github.com/can1357/oh-my-pi/tree/main/packages/collab-web";
    license = lib.licenses.mit;
    mainProgram = "omp-collab-relay";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
