{ pkgs }:
let
  runtimePath =
    pkgs.lib.makeBinPath [
      pkgs.colima
      pkgs.docker-client
      pkgs.openssh
      pkgs.coreutils
    ]
    + ":/usr/bin:/bin:/usr/sbin:/sbin";
in
pkgs.swift.stdenv.mkDerivation {
  pname = "colimabar";
  version = "0.4";

  src = pkgs.fetchFromGitHub {
    owner = "tdi";
    repo = "colimabar";
    rev = "5582e2049399d2629356cc4cfcd3f190352e0322";
    hash = "sha256-9qKLt8/m8thSHH+eql9va5zQ1HYIpjawtyAZsxdGn7E=";
  };

  patches = [
    ./_colimabar-nix.patch
    ./_colimabar-output.patch
    ./_colimabar-resources.patch
  ];
  postPatch = ''
    substituteInPlace Sources/ColimaManager.swift Sources/ColimaBarApp.swift \
      --replace-fail '@runtimePath@' '${runtimePath}'
    substituteInPlace Sources/ColimaManager.swift \
      --replace-fail '@colima@' '${pkgs.lib.getExe pkgs.colima}'
  '';

  nativeBuildInputs = [
    pkgs.swift
    pkgs.swiftpm
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Compile the actual patched manager and exercise its private subprocess runner.
    cat Sources/ColimaManager.swift ${./_colimabar-runner-test.swift} > runner-test.swift
    swiftc -parse-as-library runner-test.swift -o runner-test
    ./runner-test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    app="$out/Applications/ColimaBar.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$(swiftpmBinPath)/ColimaBar" "$app/Contents/MacOS/ColimaBar"
    cp Sources/Info.plist "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.4' "$app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 0.4' "$app/Contents/Info.plist"
    runHook postInstall
  '';

  # Sign only after all fixups; stripping or rewriting later invalidates the bundle.
  dontStrip = true;
  postFixup = ''
    /usr/bin/codesign --force --deep --sign - "$out/Applications/ColimaBar.app"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/ColimaBar.app"
  '';

  meta = {
    description = "Manual Colima VM lifecycle from the macOS menu bar";
    homepage = "https://github.com/tdi/colimabar";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.darwin;
  };
}
