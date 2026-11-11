{
  pkgs,
  src,
  version,
  meta,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "tern";
  inherit src version meta;

  nativeBuildInputs = [
    pkgs.unzip
    pkgs.makeWrapper
  ];

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  # The upstream app is signed: never strip, rewrite, or re-sign its contents.
  dontStrip = true;
  dontFixup = true;

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -a Tern.app "$out/Applications/Tern.app"
    makeWrapper "$out/Applications/Tern.app/Contents/MacOS/tern" "$out/bin/tern" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.git
          pkgs.openssh
        ]
      }

    runHook postInstall
  '';

  # Verify the signature and CLI after store registration, not in the builder.
  # Executing a signed app here can attach macOS app-management metadata before
  # Nix has canonicalised the output's filesystem attributes.
}
