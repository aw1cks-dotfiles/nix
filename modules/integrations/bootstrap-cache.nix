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
        cp ${./_cache-bootstrap}/*.sh ${./_cache-bootstrap}/*.py \
          "$out/modules/integrations/_cache-bootstrap/"
        cp ${../shared/_cache-list.nix} "$out/modules/shared/_cache-list.nix"
        cp ${../shared/_render-cache-conf.nix} "$out/modules/shared/_render-cache-conf.nix"
      '';
      app = pkgs.writeShellApplication {
        name = "bootstrap-cache";
        # Deliberately use the installed Lix, not a separately realised Nix.
        runtimeInputs = [
          pkgs.coreutils
          pkgs.diffutils
          pkgs.gawk
          pkgs.gnugrep
        ];
        text = ''
          exec ${pkgs.runtimeShell} ${source}/modules/integrations/_cache-bootstrap/bootstrap.sh "$@"
        '';
        meta.description = "Bootstrap local cache policy with explicit NixOS, nix-darwin, or standalone HM ownership";
      };
    in
    {
      packages = {
        bootstrap-cache-conf = confFile;
        bootstrap-cache = app;
      } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        cache-bootstrap-vm-test = import ./_cache-bootstrap/vm-test.nix { inherit pkgs source; };
      };

      apps.bootstrap-cache = {
        type = "app";
        program = "${app}/bin/bootstrap-cache";
        meta.description = app.meta.description;
      };

      checks.cache-bootstrap = pkgs.runCommand "cache-bootstrap-checks" {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.lix
          pkgs.shellcheck
          pkgs.diffutils
          pkgs.just
        ];
      } ''
        export HOME="$TMPDIR/home"
        export NIX_CONF_DIR="$TMPDIR/empty-nix-conf"
        mkdir -p "$HOME" "$NIX_CONF_DIR"
        directory=${source}/modules/integrations/_cache-bootstrap
        shellcheck --shell=sh --external-sources --source-path="$directory" "$directory"/*.sh
        just --justfile ${../../justfile} --list >/dev/null
        python3 "$directory/test_bootstrap.py"
        cmp ${confFile} <(nix --extra-experimental-features nix-command --store dummy:// \
          eval --offline --raw --file ${source}/modules/shared/_render-cache-conf.nix)
        touch "$out"
      '';
    };
}
