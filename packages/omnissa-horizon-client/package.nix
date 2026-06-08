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

    # The Horizon Client binary links against GTK3-x11 and crashes on
    # Wayland-native GDK backends with SIGSEGV during window creation.
    # Force x11 so it goes through XWayland and avoids the GTK3/XKB crash.
    #
    # Exec the deep ELF at lib/omnissa/horizon/bin/horizon-client directly
    # rather than the upstream ${files}/bin/horizon-client shell wrapper:
    # that wrapper prepends /usr/lib/omnissa to LD_LIBRARY_PATH, which
    # then loads Omnissa's bundled libgtkmm-3.0.so.1 (and the rest of
    # the *mm bindings) AHEAD of nixpkgs' newer versions. The nixpkgs
    # libgtk-3.so.0 / libgdk-3.so.0 in the FHS env are ABI-incompatible
    # with the older Omnissa C++ binding libs, so the client SIGSEGVs
    # early during widget initialization (gdb backtrace confirms
    # /usr/lib/omnissa/libgtkmm-3.0.so.1 loaded with assertion failures
    # in cdk_broker_view*).
    #
    # We replicate just the env that the upstream wrapper sets and
    # that we actually need (GDK_BACKEND, PATH for horizon-protocol),
    # without the LD_LIBRARY_PATH prepend that the wrapper does. PATH
    # for horizon-protocol matters because the client `exec`s that
    # helper by name during BLAST session launch; without it on PATH
    # no MKS viewctrl Unix socket is created and the session fails
    # with VDPCONNECT_FAILURE.
    runScript = writeShellScript "horizon-client-run" ''
      export GDK_BACKEND=x11
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

      # Expose host GPU drivers inside the FHS sandbox so the bundled
      # FFmpeg can hardware-decode the BLAST H.264/HEVC/AV1 video stream.
      # /run/opengl-driver on NixOS resolves to whichever
      # hardware.graphics drivers the host is using (mesa for Intel/AMD,
      # version-matched libnvidia-* + libcuda + libnvcuvid for NVIDIA via
      # hardware.nvidia.modesetting.enable), so this single path covers
      # all three vendors transparently. LIBVA_DRIVERS_PATH tells libva
      # where to find the backend driver inside that tree. For NVIDIA
      # specifically, the host must also have nvidia-vaapi-driver in
      # hardware.graphics.extraPackages for VA-API to find a backend;
      # without it the client falls back to software decode via libx264
      # (the visible symptom is ~5-15fps frame target in the protocol
      # log).
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export LIBVA_DRIVERS_PATH="/run/opengl-driver/lib/dri"

      # PATH setup:
      #  * /usr/lib/omnissa/horizon/client must come first so the client
      #    can spawn the horizon-protocol helper binary during BLAST
      #    session launch (matches what the upstream bin/horizon-client
      #    wrapper does). Without it, the helper never starts and the
      #    session fails with VDPCONNECT_FAILURE.
      #  * /etc/host-current-system/sw/bin makes host binaries available
      #    so xdg-open can launch the system browser for OAuth / SAML
      #    SSO flows.
      export PATH="/usr/lib/omnissa/horizon/client:/etc/host-current-system/sw/bin:$PATH"
      if [ -z "''${BROWSER:-}" ]; then
        for _b in firefox chromium google-chrome-stable zen-twilight zen; do
          if command -v "$_b" >/dev/null 2>&1; then
            export BROWSER="$_b"
            break
          fi
        done
      fi

      exec ${omnissaHorizonClientFiles}/lib/omnissa/horizon/bin/horizon-client "$@"
    '';
    extraBwrapArgs = [
      "--ro-bind-try"
      "/run/current-system/sw"
      "/etc/host-current-system/sw"
      # NB: /run/opengl-driver is exposed automatically by buildFHSEnv's
      # default auto-mount of /run (it walks / and bind-mounts every
      # non-ignored directory, which covers /run and therefore the
      # /run/opengl-driver symlink). Just exporting LD_LIBRARY_PATH /
      # LIBVA_DRIVERS_PATH in the runScript is enough; an explicit
      # --ro-bind-try here would attempt to re-mount a path that's
      # already bind-mounted and breaks on hosts where the symlink
      # target is in a different store path than the running system.
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
        # libva is the VA-API library that the bundled FFmpeg
        # (libavcodec.so.62.omnissa) dlopens for hardware video decode;
        # the backend driver itself comes from /run/opengl-driver via
        # LIBVA_DRIVERS_PATH set in runScript.
        libva
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
