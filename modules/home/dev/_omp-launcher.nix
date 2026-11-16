{
  lib,
  pkgs,
  package,
  settings,
  storage,
  xdg,
  configRelative ? ".omp",
}:
let
  # JSON is valid YAML; keep declarations separate from writable runtime settings.
  managedSettings = pkgs.writeText "omp-managed-settings.yml" (
    builtins.toJSON (if settings == null then { } else settings)
  );
  launcher = pkgs.writeShellScript "omp-managed" ''
    set -efu
    ${lib.optionalString (storage == "xdg") ''
      export PI_CONFIG_DIR=${lib.escapeShellArg configRelative}
      if [ -n "''${PI_CODING_AGENT_DIR-}" ]; then
        printf '%s\n' 'Unset PI_CODING_AGENT_DIR: it bypasses native XDG storage.' >&2
        exit 1
      fi
      if [ -e "$HOME/.omp/agent" ] || [ -L "$HOME/.omp/agent" ] || [ -L "$HOME/.omp" ]; then
        printf '%s\n' 'Legacy OMP config remains. Stop OMP and follow the manual move in docs/omp.md before using XDG storage.' >&2
        exit 1
      fi
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-${xdg.dataHome}}"
      export XDG_STATE_HOME="''${XDG_STATE_HOME:-${xdg.stateHome}}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-${xdg.cacheHome}}"
      export PI_NATIVES_DIR="''${PI_NATIVES_DIR:-$XDG_CACHE_HOME/omp/natives}"
      # Existing worktrees may carry absolute Git/session references.
      export OMP_WORKTREE_DIR="''${OMP_WORKTREE_DIR:-$HOME/.omp/wt}"
      # Upstream selects each XDG category only when its directory exists.
      (umask 077; ${pkgs.coreutils}/bin/mkdir -p \
        "$XDG_DATA_HOME/omp" "$XDG_STATE_HOME/omp" "$XDG_CACHE_HOME/omp")
    ''}
    # Replace inherited generations of our own overlay, while preserving
    # caller overlays later in the list (higher priority).
    caller_overlays=
    old_ifs=$IFS
    IFS=:
    for overlay in ''${PI_CONFIG_FILES-}; do
      case "$overlay" in
        ""|${builtins.storeDir}/*-omp-managed-settings.yml) ;;
        *) caller_overlays="''${caller_overlays:+$caller_overlays:}$overlay" ;;
      esac
    done
    IFS=$old_ifs
    export PI_CONFIG_FILES="${managedSettings}''${caller_overlays:+:$caller_overlays}"
    exec ${lib.getExe package} "$@"
  '';
in
pkgs.symlinkJoin {
  name = "omp-managed-${package.version or "unknown"}";
  version = package.version or "unknown";
  paths = [ package ];
  postBuild = ''
    rm "$out/bin/omp"
    cp ${launcher} "$out/bin/omp"
  '';
  passthru = {
    unwrapped = package;
    inherit managedSettings;
  };
  meta = (package.meta or { }) // {
    mainProgram = "omp";
  };
}
