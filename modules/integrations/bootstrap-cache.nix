{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      render = import ../shared/_render-cache-conf.nix;
      confFile = pkgs.writeText "aw1cks-caches.conf" (render { });

      # Same layout as a checkout. The first-bootstrap path uses the source
      # directly; this packaged entry point is a convenience after bootstrap.
      source = pkgs.runCommand "cache-bootstrap-source" { } ''
        mkdir -p "$out/modules/integrations/_cache-bootstrap" "$out/modules/shared"
        cp ${./_cache-bootstrap}/*.py \
          "$out/modules/integrations/_cache-bootstrap/"
        cp ${../shared/_cache-list.nix} "$out/modules/shared/_cache-list.nix"
        cp ${../shared/_render-cache-conf.nix} "$out/modules/shared/_render-cache-conf.nix"
      '';
      app = pkgs.writeShellApplication {
        name = "bootstrap-cache";
        # Deliberately use the installed Lix, not a separately realised Nix.
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec python3 -I -S ${source}/modules/integrations/_cache-bootstrap/bootstrap.py "$@"
        '';
        meta.description = "Bootstrap local cache policy with explicit NixOS, nix-darwin, or standalone HM ownership";
      };
    in
    {
      packages = {
        bootstrap-cache-conf = confFile;
        bootstrap-cache = app;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        cache-bootstrap-vm-test = import ./_cache-bootstrap/vm-test.nix { inherit pkgs source; };
      };

      apps.bootstrap-cache = {
        type = "app";
        program = "${app}/bin/bootstrap-cache";
        meta.description = app.meta.description;
      };

      checks.cache-bootstrap =
        pkgs.runCommand "cache-bootstrap-checks"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.lix
              pkgs.diffutils
              pkgs.gitMinimal
            ];
          }
          ''
            export HOME="$TMPDIR/home"
            export NIX_CONF_DIR="$TMPDIR/empty-nix-conf"
            export NIX_CONFIG=""
            export NIX_USER_CONF_FILES=/dev/null
            export XDG_CONFIG_HOME="$TMPDIR/xdg"
            export XDG_CONFIG_DIRS="$TMPDIR/xdg-system"
            export XDG_CACHE_HOME="$TMPDIR/cache"
            export XDG_STATE_HOME="$TMPDIR/state"
            mkdir -p "$HOME" "$NIX_CONF_DIR" "$XDG_CONFIG_HOME" "$XDG_CONFIG_DIRS" \
              "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
            directory=${source}/modules/integrations/_cache-bootstrap
            export PYTHONDONTWRITEBYTECODE=1
            python3 -m unittest discover --start-directory "$directory" --pattern 'test_*.py' --verbose
            # Exercise the source CLI, including explicit function application.
            # Its standard-install guard rejects the sandbox's NIX_CONF_DIR. The
            # renderer itself uses a dummy store and cannot realise dependencies.
            env -u NIX_CONF_DIR python3 -I -S "$directory/bootstrap.py" render > source.conf
            cmp ${confFile} source.conf
            touch "$out"
          '';
    };
}
