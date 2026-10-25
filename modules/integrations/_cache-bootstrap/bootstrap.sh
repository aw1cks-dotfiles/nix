#!/bin/sh
# Source-level exception to flake-app tooling: this must run before nix run can.
set -eu

here=$(CDPATH='' cd -- "$(dirname "$0")" && pwd -P)
renderer="$here/../../shared/_render-cache-conf.nix"

fail() { printf 'bootstrap-cache: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [--yes] [--recovery] COMMAND [ARGUMENTS]
  bootstrap nixos|darwin|standalone-hm LOCAL-FLAKE#NAME
  sync-caches                  Provision/update standalone daemon caches
  check-caches                 Check file drift and daemon connection (not substitution)
  probe STORE-PATH              Request an absent signed path through the daemon
  render [extra|replace|official]

Requires an installed Lix and a reviewed checkout; just and flake apps are optional.
--yes       Approve changes non-interactively (still displays the intended policy).
--recovery  System bootstrap: official-cache-only policy, replacing inherited lists.
            Standalone HM/sync: replace the owned fragment from the current inventory;
            inherited/externally managed stale entries must be removed by their owner.
USAGE
}

approve() {
  [ "$yes" = true ] && return 0
  printf 'Continue? [y/N] ' > /dev/tty || fail 'No terminal; review first, then use --yes.'
  IFS= read -r answer < /dev/tty || fail 'Confirmation aborted.'
  case "$answer" in y|Y|yes) ;; *) fail 'Cancelled.' ;; esac
}

# Do not make an install/recovery operation depend on the caller's client config.
# --offline and disabled IFD guarantee this renderer does not realise an app.
render() {
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null "$nix" \
    --extra-experimental-features nix-command \
    --option allow-import-from-derivation false \
    eval --offline --raw --file "$renderer" --argstr mode "$1"
}

# The elevated invocation gets only intentional Nix environment variables. In
# particular, never carry a caller's NIX_CONFIG (which can contain root hooks).
privileged() {
  case "$(uname -s)" in Darwin) root_home=/var/root ;; *) root_home=/root ;; esac
  # Do not put user-writable profile/bin directories on root's search path.
  root_path=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin
  if [ "$(id -u)" -eq 0 ]; then
    /usr/bin/env -i HOME="$root_home" PATH="$root_path" "$@"
  else
    sudo -- /usr/bin/env -i HOME="$root_home" PATH="$root_path" "$@"
  fi
}

system_bootstrap() {
  owner=$1; target=$2
  case "$owner:$(uname -s)" in
    nixos:Linux) [ -e /run/current-system/nixos-version ] || fail 'nixos requires a NixOS host/installer.' ;;
    darwin:Darwin) ;;
    *) fail "Owner $owner does not match this OS." ;;
  esac
  mode=extra
  [ "$recovery" = false ] || mode=official
  policy=$(render "$mode")
  config="extra-experimental-features = nix-command flakes
accept-flake-config = false
require-sigs = true
fallback = false
$policy"
  printf '%s\n' "First activation ($owner): $target" "$policy" >&2
  [ "$recovery" = false ] || printf '%s\n' 'Recovery uses only the official cache; missing substitutes may require builds.' >&2
  printf '%s\n' 'Missing substitutes can cause local builds, including the kernel; cache coverage is not guaranteed.' >&2
  approve
  if [ "$owner" = nixos ]; then
    rebuild=$(command -v nixos-rebuild) || fail 'nixos-rebuild is not installed.'
    privileged NIX_CONFIG="$config" NIX_USER_CONF_FILES=/dev/null NIX_REMOTE=daemon \
      "$rebuild" switch --flake "$target"
  else
    privileged NIX_CONFIG="$config" NIX_USER_CONF_FILES=/dev/null NIX_REMOTE=daemon \
      "$nix" --store daemon run --no-write-lock-file "$flake#darwin" -- switch --flake "$target"
  fi
  printf '%s\n' 'Activation completed. Re-run check-caches without temporary overrides; no bootstrap file was installed.'
}

sync_caches() {
  # The root helper independently validates the policy received on stdin. It
  # never evaluates user Nix code as root or installs a user-owned symlink.
  policy=$(render extra)
  printf '%s\n' 'Standalone daemon policy: /etc/nix/aw1cks-caches.conf' "$policy" >&2
  printf '%s\n' 'This restarts the daemon and can interrupt concurrent builds.' >&2
  approve
  printf '%s\n' "$policy" | privileged \
    /bin/sh "$here/daemon.sh" "$nix"
  # A new, unprivileged connection is a liveness check, not a substitution claim.
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null "$nix" \
    --extra-experimental-features nix-command --store daemon store ping >/dev/null
  printf '%s\n' 'Daemon responds. Use probe with an absent signed store path to test substitution.'
}

check_caches() {
  expected=$(render extra)
  if [ -f /etc/nix/aw1cks-caches.conf ]; then
    actual=$(cat /etc/nix/aw1cks-caches.conf)
    [ "$expected" = "$actual" ] || fail 'Standalone daemon fragment differs from this inventory; run sync-caches.'
    grep -Fqx 'include /etc/nix/aw1cks-caches.conf' /etc/nix/nix.conf ||
      fail 'Standalone fragment exists but its include is missing.'
    printf '%s\n' 'Standalone fragment matches the inventory.'
  else
    printf '%s\n' 'No standalone fragment (expected for declaratively managed hosts).'
  fi
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null "$nix" \
    --extra-experimental-features nix-command config show substituters
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null "$nix" \
    --extra-experimental-features nix-command config show trusted-public-keys
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null "$nix" \
    --extra-experimental-features nix-command --store daemon store ping
  printf '%s\n' 'Above settings are a client view, NOT a daemon-policy dump; substitution is unverified.'
}

probe() {
  [ "$(id -u)" -ne 0 ] || fail 'Run probe as the ordinary HM/build user, not root.'
  printf '%s\n' "$1" | grep -Eq '^/nix/store/[0-9a-z]{32}-[A-Za-z0-9+._?=-]+$' ||
    fail 'probe expects one complete /nix/store path.'
  [ ! -e "$1" ] || fail 'Path already exists; choose an absent fixture. Nothing was removed.'
  nix_store="${nix%/*}/nix-store"
  [ -x "$nix_store" ] || fail 'The installed Lix is missing nix-store.'
  NIX_CONFIG='extra-experimental-features = nix-command flakes
accept-flake-config = false
require-sigs = true' NIX_USER_CONF_FILES=/dev/null NIX_REMOTE=daemon \
    "$nix_store" --realise "$1" --option max-jobs 0 --option extra-local-jobs 0 --option builders ''
  printf '%s\n' 'Daemon realised the requested path with local/remote builds disabled.'
}

yes=false; recovery=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes) yes=true; shift ;;
    --recovery) recovery=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --*) fail "Unknown option: $1" ;;
    *) break ;;
  esac
done
[ "$#" -gt 0 ] || { usage; exit 1; }
command=$1; shift
nix=$(command -v nix) || fail 'Install Lix first; no attempt was made to fetch bootstrap tools.'
case "$(NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null "$nix" --version)" in *Lix*|*lix*) ;; *) fail 'This draft supports Lix; upstream/Determinate Nix is not validated.' ;; esac
[ "${NIX_CONF_DIR:-/etc/nix}" = /etc/nix ] || fail 'Nonstandard NIX_CONF_DIR requires an explicit service adapter.'
# Do not let an inherited remote-store selection redirect provisioning/checks.
unset NIX_REMOTE NIX_CONF_DIR

case "$command" in
  render) [ "$#" -le 1 ] || fail 'render takes at most one mode.'; render "${1:-extra}" ;;
  sync-caches) [ "$#" -eq 0 ] || fail 'sync-caches takes no arguments.'; sync_caches ;;
  check-caches) [ "$#" -eq 0 ] || fail 'check-caches takes no arguments.'; check_caches ;;
  probe) [ "$#" -eq 1 ] || fail 'probe takes one store path.'; probe "$1" ;;
  bootstrap)
    [ "$#" -eq 2 ] || fail 'bootstrap requires an explicit owner and LOCAL-FLAKE#NAME.'
    owner=$1; target=$2
    case "$target" in *'#'*) flake=${target%%#*}; name=${target#*#} ;; *) fail 'Target must include #NAME.' ;; esac
    case "$name" in ''|*[!A-Za-z0-9._@-]*) fail 'Target name contains unsupported characters.' ;; esac
    [ -d "$flake" ] && [ -f "$flake/flake.nix" ] || fail 'Target must be a reviewed local flake checkout.'
    flake=$(CDPATH='' cd -- "$flake" && pwd -P)
    target="$flake#$name"
    case "$owner" in
      nixos|darwin) system_bootstrap "$owner" "$target" ;;
      standalone-hm)
        [ "$(id -u)" -ne 0 ] || fail 'Run HM bootstrap as the target user; only provisioning uses sudo.'
        sync_caches
        NIX_CONFIG='extra-experimental-features = nix-command flakes
accept-flake-config = false
require-sigs = true' NIX_USER_CONF_FILES=/dev/null NIX_REMOTE=daemon \
          "$nix" --store daemon run --no-write-lock-file "$flake#home-manager" -- switch --flake "$target"
        ;;
      *) fail 'Owner must be nixos, darwin, or standalone-hm.' ;;
    esac
    ;;
  *) fail "Unknown command: $command" ;;
esac
