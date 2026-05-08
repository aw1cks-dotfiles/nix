{
  lib,
  stdenv,
  buildFHSEnv,
  callPackage,
  copyDesktopItems,
  gsettings-desktop-schemas,
  makeDesktopItem,
  writeTextDir,
  gdk-pixbuf,
  librsvg,
  configText ? "",
}:
let
  version = "2603";

  omnissaHorizonClientFiles = callPackage ./files.nix { };

  mainProgram = "horizon-client";

  fhsEnv = buildFHSEnv {
    pname = "horizon-client";
    inherit version;

    # In 2603 the upstream binary handles its own environment setup.
    # We point directly at the ELF; the FHS env provides the required libs.
    runScript = "${omnissaHorizonClientFiles}/lib/omnissa/horizon/bin/horizon-client";

    targetPkgs =
      pkgs: with pkgs; [
        at-spi2-atk
        atk
        cairo
        dbus
        file
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk2
        gtk3-x11
        harfbuzz
        liberation_ttf
        libjpeg
        libpng
        libpulseaudio
        libtiff
        libudev0-shim
        libuuid
        libv4l
        pango
        pcsclite
        pixman
        udev
        omnissaHorizonClientFiles
        xorg.libX11
        xorg.libXau
        xorg.libXcursor
        xorg.libXext
        xorg.libXi
        xorg.libXinerama
        xorg.libxkbfile
        xorg.libXrandr
        xorg.libXrender
        xorg.libXScrnSaver
        xorg.libXtst
        zlib
        libxml2_13
        librsvg
        xkeyboard-config
        (writeTextDir "etc/omnissa/config" configText)
      ];

    # Regenerate gdk-pixbuf loaders.cache to include the librsvg SVG loader.
    extraBuildCommands = ''
      cache_dir=$out/usr/lib64/gdk-pixbuf-2.0/2.10.0
      cache=$cache_dir/loaders.cache
      if [ -f "$cache" ]; then
        rm -f "$cache"
        ${gdk-pixbuf.dev}/bin/gdk-pixbuf-query-loaders \
          ${gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
          ${librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
          > "$cache"
      fi
    '';
  };

  desktopItem = makeDesktopItem {
    name = "horizon-client";
    desktopName = "Omnissa Horizon Client";
    icon = "${omnissaHorizonClientFiles}/share/icons/horizon-client.png";
    exec = "${fhsEnv}/bin/horizon-client %u";
    mimeTypes = [
      "x-scheme-handler/horizon-client"
      "x-scheme-handler/vmware-view"
    ];
  };

in
stdenv.mkDerivation {
  pname = "omnissa-horizon-client";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ln -s ${fhsEnv}/bin/horizon-client $out/bin/
    runHook postInstall
  '';

  meta = {
    inherit mainProgram;
    description = "Omnissa Horizon Client (with SVG/XKB fixes)";
    homepage = "https://www.omnissa.com/products/horizon-8/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ mhutter ];
  };
}
