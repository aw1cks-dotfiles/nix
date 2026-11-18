{ pkgs }:
let
  pname = "learnharness";
  inherit (import ./_sources.nix) version changelog artifacts;
  src = pkgs.fetchurl artifacts.${pkgs.stdenv.hostPlatform.system};
  meta = {
    description = "Desktop app for adaptive teaching and practice";
    homepage = "https://learnharness.ai/";
    inherit changelog;
    license = pkgs.lib.licenses.agpl3Only;
    mainProgram = pname;
    platforms = builtins.attrNames artifacts;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
in
if pkgs.stdenv.hostPlatform.isDarwin then
  pkgs.stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      src
      meta
      ;
    nativeBuildInputs = [ pkgs.undmg ];
    sourceRoot = ".";
    dontBuild = true;
    # Preserve the notarized bundle, including all nested signatures and symlinks.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -a LearnHarness.app "$out/Applications/"
      cat > "$out/bin/learnharness" <<EOF
      #!${pkgs.runtimeShell}
      exec /usr/bin/open -a "$out/Applications/LearnHarness.app" --args "\$@"
      EOF
      chmod +x "$out/bin/learnharness"
      runHook postInstall
    '';
  }
else
  let
    contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
  in
  pkgs.appimageTools.wrapType2 {
    inherit
      pname
      version
      src
      meta
      ;
    extraInstallCommands = ''
      install -Dm644 ${contents}/learnharness.desktop "$out/share/applications/learnharness.desktop"
      substituteInPlace "$out/share/applications/learnharness.desktop" \
        --replace-fail 'Exec=AppRun' 'Exec=learnharness'
      cp -r ${contents}/usr/share/icons "$out/share/"
    '';
  }
