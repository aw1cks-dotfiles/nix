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
        # 2603 ships only the omnissa-bundled libglibmm-2.4.so.1 (backfilled
        # from 2512); the horizon-client binary additionally NEEDs the
        # libglibmm_generate_extra_defs helper, so pull in the full GTK3 C++
        # bindings stack.
        glibmm
        gtk2
        gtk3-x11
        gtkmm3
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
        # 26.05: 'xorg.lib*' attrs were renamed to the flat 'lib*' attrs.
        libx11
        libxau
        libxcursor
        libxext
        libxi
        libxinerama
        libxkbfile
        libxrandr
        libxrender
        libxscrnsaver
        libxtst
        zlib
        libxml2_13
        librsvg
        xkeyboard-config
        # The 2603 .x64.tar.gz layout no longer bundles libcrypto.so.3 or
        # libcurl.so.4 alongside the binary like the older multi-arch tarball
        # did, so provide them via the FHS env.
        openssl
        curl
        # Required so the OAuth/SAML SSO browser flow can find the
        # system browser via xdg-open. Without this, sign-in silently
        # fails for connection servers that require browser SSO.
        xdg-utils
        omnissaHorizonClientFiles
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

  # Two desktop entries: a visible launcher with no field codes, and a
  # hidden URI handler with %u + MimeType. Splitting these out matters
  # because some launchers (e.g. Noctalia) pass desktop entry field
  # codes through as literal CLI arguments instead of stripping them
  # per the spec, which makes the app treat "%u" as a connection URL
  # and exit immediately.
  launcherDesktopItem = makeDesktopItem {
    name = "horizon-client";
    desktopName = "Omnissa Horizon Client";
    icon = "${omnissaHorizonClientFiles}/share/icons/horizon-client.png";
    exec = "${fhsEnv}/bin/horizon-client";
    categories = [ "Network" ];
  };

  uriHandlerDesktopItem = makeDesktopItem {
    name = "horizon-client-uri-handler";
    desktopName = "Omnissa Horizon Client (URI handler)";
    noDisplay = true;
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

  desktopItems = [
    launcherDesktopItem
    uriHandlerDesktopItem
  ];

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
