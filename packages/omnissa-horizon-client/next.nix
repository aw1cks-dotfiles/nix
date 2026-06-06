# Horizon Client Next — .NET/Avalonia rewrite of the classic GTK3 client.
# Ships in the same tarball as the classic client under
# lib/omnissa/horizon/bin/horizon-client-next-bundle/.
# Does not use GTK3 or gdk-pixbuf; avoids the GTK/XWayland/XKB bugs entirely.
{
  lib,
  stdenv,
  buildFHSEnv,
  callPackage,
  copyDesktopItems,
  makeDesktopItem,
  writeShellScript,
  # Provides libstdc++.so.6 for libcoreclr.so
  gcc-unwrapped,
  # For compiling the HID stub shim
  systemd,
  # GSettings schemas needed by the omnissa proxy detection code
  gsettings-desktop-schemas,
  # .NET/Avalonia runtime deps
  fontconfig,
  freetype,
  harfbuzz,
  icu,
  libGL,
  libX11,
  libxkbcommon,
  openssl,
  zlib,
  # System deps
  dbus,
  glib,
  pango,
  cairo,
  libpulseaudio,
  udev,
  libuuid,
  libpng,
  libjpeg,
  pcsclite,
}:
let
  version = "2603";

  omnissaHorizonClientFiles = callPackage ./files.nix { };

  bundleDir = "${omnissaHorizonClientFiles}/lib/omnissa/horizon/bin/horizon-client-next-bundle";

  # libclientSdkCPrimitive.so 2512.0 crashes in CdkClientInfo_GetHIDInfo with
  # a null-deref when enumerating udev "input" devices. This preload shim
  # intercepts udev_enumerate_scan_devices for the input subsystem and returns
  # an empty list instead of letting the buggy code dereference a null parent.
  hidStub = stdenv.mkDerivation {
    name = "horizon-client-next-hid-stub";
    src = ./hid-stub.c;
    dontUnpack = true;
    nativeBuildInputs = [ ];
    buildInputs = [ systemd ];
    buildPhase = ''
      $CC -shared -fPIC -O2 -o libhorizon-hid-stub.so $src \
        -I${lib.getDev systemd}/include \
        -ldl
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp libhorizon-hid-stub.so $out/lib/
    '';
  };

  runScript = writeShellScript "horizon-client-next-run" ''
    # Avoid host .NET settings interfering with the bundled runtime.
    unset DOTNET_ROOT
    unset DOTNET_HOST_PATH
    unset DOTNET_MULTILEVEL_LOOKUP
    unset DOTNET_SHARED_STORE
    unset DOTNET_STARTUP_HOOKS
    unset COREHOST_TRACE
    unset COREHOST_TRACEFILE

    # CoreCLR requires write access to load and patch DLL relocations.
    # The nix store is mounted read-only, so we create a per-session cache dir
    # and use DOTNET_EnableWriteXorExecute=0 + a writable shadow copy.
    # We run the binary from a tmpdir copy so /proc/self/exe resolves writably,
    # and set APP_CONTEXT_BASE_DIRECTORY so TPA resolves from the tmpdir too.
    bundle_tmp=$(mktemp -d -t horizon-client-next-XXXXXX)
    trap 'rm -rf "$bundle_tmp"' EXIT
    cp -r "${bundleDir}/." "$bundle_tmp/"
    chmod -R u+w "$bundle_tmp"

    export DOTNET_EnableWriteXorExecute=0
    export APP_CONTEXT_BASE_DIRECTORY="$bundle_tmp/"
    # libclientSdkCPrimitive.so is at $files/lib/; crtbora/omnissabase at $files/lib/omnissa/.
    export LD_LIBRARY_PATH="$bundle_tmp:${omnissaHorizonClientFiles}/lib:${omnissaHorizonClientFiles}/lib/omnissa:${gcc-unwrapped.lib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # Work around null-deref crash in CdkClientInfo_GetHIDInfo (still present in 2603).
    export LD_PRELOAD="${hidStub}/lib/libhorizon-hid-stub.so''${LD_PRELOAD:+:$LD_PRELOAD}"
    # libclientSdkCPrimitive.so calls g_settings_new("org.gnome.system.proxy")
    # during proxy detection. The schema must be present or glib will abort.
    export XDG_DATA_DIRS="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:/usr/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    exec "$bundle_tmp/horizon-client-next" "$@"
  '';

  fhsEnv = buildFHSEnv {
    pname = "horizon-client-next";
    inherit version;
    runScript = runScript;

    targetPkgs =
      pkgs: with pkgs; [
        # libclientSdkCPrimitive.so requires the full GTK3 + C++ bindings stack
        at-spi2-atk
        atk
        cairo
        curl
        dbus
        file
        fontconfig
        freetype
        gdk-pixbuf
        glib
        glibmm
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
        # .NET / Avalonia runtime extras
        icu
        libGL
        libxkbcommon
        openssl
        libice
        libsm
        xkeyboard-config
        omnissaHorizonClientFiles
      ];
  };

  desktopItem = makeDesktopItem {
    name = "horizon-client-next";
    desktopName = "Omnissa Horizon Client Next";
    icon = "${omnissaHorizonClientFiles}/share/icons/horizon-client.png";
    exec = "${fhsEnv}/bin/horizon-client-next %u";
    mimeTypes = [
      "x-scheme-handler/horizon-client"
      "x-scheme-handler/vmware-view"
    ];
  };

in
stdenv.mkDerivation {
  pname = "omnissa-horizon-client-next";
  inherit version;

  dontUnpack = true;
  # strip -S corrupts PE/CLI .NET assemblies (System.Private.CoreLib.dll etc.)
  # which causes CoreCLR to fail with COR_E_BADIMAGEFORMAT (0x8007000B).
  dontStrip = true;

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ln -s ${fhsEnv}/bin/horizon-client-next $out/bin/horizon-client-next
    runHook postInstall
  '';

  meta = {
    mainProgram = "horizon-client-next";
    description = "Omnissa Horizon Client Next (.NET/Avalonia, no GTK3/XKB issues)";
    homepage = "https://www.omnissa.com/products/horizon-8/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
