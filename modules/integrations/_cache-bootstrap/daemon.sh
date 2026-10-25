#!/bin/sh
# Invoked only after the user has reviewed/approved the rendered cache policy.
set -eu
[ "$(id -u)" -eq 0 ] || { echo 'cache-provision: root is required.' >&2; exit 1; }
[ "$#" -eq 1 ] || { echo 'cache-provision: expected the installed Lix executable.' >&2; exit 1; }
cache_nix=$1
here=$(CDPATH='' cd -- "$(dirname "$0")" && pwd -P)
# shellcheck source=daemon-lib.sh
. "$here/daemon-lib.sh"

case "$cache_nix" in /*) ;; *) cache_error 'Lix executable must be an absolute path.'; exit 1 ;; esac
case "$("$cache_nix" --version)" in *Lix*|*lix*) ;; *) cache_error 'Installed client is not Lix.'; exit 1 ;; esac
[ ! -e /run/current-system/nixos-version ] && [ ! -e /run/current-system/darwin-version ] || {
  cache_error 'NixOS/nix-darwin owns this daemon. Use its declarative configuration.'; exit 1;
}
[ "${NIX_CONF_DIR:-/etc/nix}" = /etc/nix ] || { cache_error 'Nonstandard daemon config requires an adapter.'; exit 1; }
[ ! -e /etc/nix/conf.d/dendritic-caches.conf ] || {
  cache_error 'Legacy dendritic-caches.conf exists; inspect its includes and migrate it first (see docs/cache-bootstrap.md).'; exit 1;
}
unset NIX_CONF_DIR NIX_REMOTE NIX_CONFIG NIX_USER_CONF_FILES
case "$(uname -s)" in
  Linux)
    cache_service=systemd
    [ "$(systemctl show nix-daemon.service --property=LoadState --value)" = loaded ] || {
      cache_error 'Expected nix-daemon.service is not loaded.'; exit 1;
    }
    service_config=$(systemctl cat nix-daemon.service)
    case "$service_config" in
      *NIX_CONF_DIR*|*NIX_CONFIG*|*NIX_USER_CONF_FILES*|*EnvironmentFile=*|*--option*|*--substituters*|*--trusted-public-keys*)
        cache_error 'Daemon has configuration/environment overrides; review a service-specific adapter.'; exit 1 ;;
    esac
    ;;
  Darwin)
    cache_service=launchd
    plist=/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    cache_secure "$plist"
    launchctl print system/org.nixos.nix-daemon >/dev/null || {
      cache_error 'Expected launchd daemon is not loaded.'; exit 1;
    }
    service_config=$(plutil -convert xml1 -o - "$plist")
    case "$service_config" in
      *NIX_CONF_DIR*|*NIX_CONFIG*|*NIX_USER_CONF_FILES*|*--option*|*--substituters*|*--trusted-public-keys*)
        cache_error 'Daemon has configuration overrides; review a service-specific adapter.'; exit 1 ;;
    esac
    ;;
  *) cache_error 'Only systemd Linux and launchd macOS are supported.'; exit 1 ;;
esac
cache_transaction /etc/nix
