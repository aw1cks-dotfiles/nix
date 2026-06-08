{
  lib,
  stdenv,
  buildFHSEnv,
  callPackage,
  copyDesktopItems,
  gsettings-desktop-schemas,
  makeDesktopItem,
  writeShellScript,
  writeTextDir,
  configText ? "",
}:
let
  version = "2603";

  omnissaHorizonClientFiles = callPackage ./files.nix { };

  mainProgram = "horizon-client";

  fhsEnv = buildFHSEnv {
    pname = "horizon-client";
    inherit version;

    # Exec the upstream bin/horizon-client shell wrapper (NOT the deep
    # ELF directly): the wrapper does GDK_BACKEND=x11, LD_LIBRARY_PATH,
    # LIBVA_DRI3_DISABLE, and crucially `export PATH="$binPath/client:$PATH"`
    # so the helper binary at /usr/lib/omnissa/horizon/client/horizon-protocol
    # is found when the client tries to spawn it during BLAST session
    # launch. Without that, the helper never starts, no MKS viewctrl
    # Unix socket is created, and the session fails with
    # VDPCONNECT_FAILURE.
    runScript = writeShellScript "horizon-client-run" ''
      # The host uses adw-gtk3-dark which isn't in the FHS sandbox; fall
      # back to Adwaita:dark (bundled with gtk3-x11) to avoid GTK widget
      # assertion failures in cdk_broker_view that lead to SIGSEGV.
      # Originally diagnosed against 2512-era ABI-mismatched libs; with
      # the multi-arch 2603 tarball this may no longer be needed but is
      # left in place pending interactive verification.
      export GTK_THEME="Adwaita:dark"

      # libclientSdkCPrimitive.so calls g_settings_new("org.gnome.system.proxy")
      # during proxy detection. The schema must be present or glib will abort.
      export XDG_DATA_DIRS="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:/usr/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

      # Make host binaries available so xdg-open can launch the system
      # browser for OAuth/SAML SSO flows (same approach as -next client).
      export PATH="/etc/host-current-system/sw/bin:$PATH"
      if [ -z "''${BROWSER:-}" ]; then
        for _b in firefox chromium google-chrome-stable zen-twilight zen; do
          if command -v "$_b" >/dev/null 2>&1; then
            export BROWSER="$_b"
            break
          fi
        done
      fi

      exec ${omnissaHorizonClientFiles}/bin/horizon-client "$@"
    '';
    extraBwrapArgs = [
      "--ro-bind-try"
      "/run/current-system/sw"
      "/etc/host-current-system/sw"
    ];

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
        # GSettings schema for org.gnome.system.proxy (proxy detection).
        gsettings-desktop-schemas
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
