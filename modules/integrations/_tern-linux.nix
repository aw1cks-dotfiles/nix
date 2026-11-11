# Adapted from pelikanade/flake's Tern packaging, with 0.9.13's inspected
# runtime dependencies: https://github.com/pelikanade/flake/blob/main/modules/packages/tern/default.nix
{
  pkgs,
  src,
  version,
  meta,
}:
let
  inherit (pkgs) lib;
  desktop = import ./_tern-desktop.nix;

  # These are dlopened, so autoPatchelf cannot infer them from DT_NEEDED.
  # WebKitGTK is the upstream fallback when WPE WebKit is unavailable.
  runtimeLibraries = with pkgs; [
    vulkan-loader
    libGL
    libxcb
    libxkbcommon
    wayland
    webkitgtk_4_1
    libpulseaudio
    pipewire
    pam
  ];
  runtimeHelpers = with pkgs; [
    desktop-file-utils
    git
    glib
    openssh
    gtk3
    libnotify
    xdg-utils
  ];
  desktopItem =
    attrs:
    pkgs.makeDesktopItem (
      {
        desktopName = "Tern";
        icon = desktop.applicationId;
        terminal = false;
        startupWMClass = desktop.applicationId;
      }
      // attrs
    );
in
pkgs.stdenv.mkDerivation {
  pname = "tern";
  inherit version src meta;

  sourceRoot = "tern";
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    wrapGAppsHook3
  ];
  buildInputs = [
    pkgs.stdenv.cc.libc
    pkgs.stdenv.cc.cc.lib
    pkgs.glib
    pkgs.gtk3
    pkgs.glib-networking
    pkgs.gsettings-desktop-schemas
  ]
  ++ runtimeLibraries;

  # Keep GTK schemas, GIO modules and WebKit's inherited toolkit environment in
  # the same wrapper as the command-line helpers, rather than wrapping twice.
  dontWrapGApps = true;

  # Patch exactly once in postFixup, before running upstream's icon renderer.
  dontAutoPatchelf = true;
  appendRunpaths = [
    (lib.makeLibraryPath runtimeLibraries)
    # autoPatchelf replaces earlier RPATHs; append the host GPU driver path here
    # rather than using addDriverRunpath before autoPatchelf runs.
    "/run/opengl-driver/lib"
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 tern "$out/libexec/tern"
    runHook postInstall
  '';

  postFixup = ''
    autoPatchelf "$out"
    makeWrapper "$out/libexec/tern" "$out/bin/tern" \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath runtimeHelpers}

    # Never let a manually installed tern earlier on PATH bypass this wrapper.
    for entry in "$out"/share/applications/so.stencil.tern*.desktop; do
      substituteInPlace "$entry" --replace-fail "Exec=tern" "Exec=$out/bin/tern"
    done

    # The archives contain only the executable. `register` renders the real
    # embedded icons without opening a GUI. Never register into the user's HOME
    # or install its generated desktop entries, whose Exec bypasses our wrapper.
    (
      export HOME="$TMPDIR/tern-register-home"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"
      export XDG_RUNTIME_DIR="$HOME/.run"
      unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
      mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" \
        "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      timeout 120 "$out/bin/tern" register

      iconRoot="$XDG_DATA_HOME/icons"
      shopt -s nullglob
      icons=("$iconRoot"/hicolor/*/apps/so.stencil.tern.png)
      if (( ''${#icons[@]} == 0 )); then
        echo "Tern registration did not generate its application icons" >&2
        exit 1
      fi
      for icon in "''${icons[@]}"; do
        install -Dm644 "$icon" "$out/share/icons/''${icon#"$iconRoot"/}"
      done
    )
  '';

  # Launch the public wrapper, not libexec/tern. Preserve upstream's application
  # identity, terminal argument convention, file handlers and URL scheme.
  desktopItems = [
    (desktopItem {
      name = "so.stencil.tern";
      exec = "tern";
      categories = [
        "System"
        "TerminalEmulator"
      ];
      extraConfig."X-TerminalArgExec" = "-e";
    })
    (desktopItem {
      name = "so.stencil.tern.url";
      exec = "tern --open-url %u";
      noDisplay = true;
      mimeTypes = [ "x-scheme-handler/tern" ];
    })
    (desktopItem {
      name = "so.stencil.tern.open";
      exec = "tern --open-file %f";
      noDisplay = true;
      mimeTypes = desktop.mimeTypes;
    })
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/tern-version-home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export TERN_CONFIG_DIR="$HOME/tern"
    mkdir -p "$HOME" "$TERN_CONFIG_DIR"
    versionOutput=$("$out/bin/tern" --version)
    case "$versionOutput" in
      "tern ${version} "*) ;;
      *) printf 'Unexpected Tern version: %s\n' "$versionOutput" >&2; exit 1 ;;
    esac
    runHook postInstallCheck
  '';
}
