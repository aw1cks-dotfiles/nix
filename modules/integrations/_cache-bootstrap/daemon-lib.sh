# POSIX helpers shared by the privileged entry point and filesystem tests.
# This file is a library: sourcing it does not modify the host.

cache_error() { printf 'cache-provision: %s\n' "$*" >&2; return 1; }
cache_stat() {
  case "$(uname -s)" in
    Darwin) stat -f '%u:%Lp' "$1" ;;
    *) stat -c '%u:%a' "$1" ;;
  esac
}
cache_secure() {
  [ ! -L "$1" ] || { cache_error "Refusing symlink: $1"; return 1; }
  meta=$(cache_stat "$1") || return 1
  [ "${meta%%:*}" = 0 ] || { cache_error "Not root-owned: $1"; return 1; }
  mode=${meta#*:}
  [ "$((0$mode & 022))" -eq 0 ] || { cache_error "Group/other writable: $1"; return 1; }
}

cache_fragment_valid() {
  # Only the renderer's two settings and two comment lines are accepted. No
  # include, hook, trusted-user, require-sigs, or arbitrary configuration input.
  awk '
    NR == 1 { if ($0 != "# Managed by aw1cks cache bootstrap v1") exit 1; next }
    NR == 2 { if ($1 != "#" || $2 != "Inventory" || $3 != "sha256:" ||
                  length($4) != 64 || $4 !~ /^[a-f0-9]+$/ || NF != 4) exit 1; next }
    NR == 3 {
      if ($1 != "extra-substituters" || $2 != "=") exit 1
      for (i=3; i<=NF; i++) if ($i !~ /^https:\/\/[A-Za-z0-9./_?=&%:+~-]+$/) exit 1
      next
    }
    NR == 4 {
      if ($1 != "extra-trusted-public-keys" || $2 != "=") exit 1
      for (i=3; i<=NF; i++) {
        if (split($i, p, ":") != 2 || p[1] !~ /^[A-Za-z0-9._-]+$/ ||
            length(p[2]) != 44 || p[2] !~ /^[A-Za-z0-9+\/]+=$/) exit 1
      }
      next
    }
    NR > 4 { exit 1 }
    END { if (NR != 4) exit 1 }
  ' "$1" || { cache_error 'Unrecognized or unsafe fragment; review it manually.'; return 1; }
}

cache_values() {
  awk -v key="$2" '$1 == key && $2 == "=" { for (i=3; i<=NF; i++) print $i }' "$1"
}

cache_main_candidate() {
  # Reject partial/foreign blocks and references outside our exact owned block.
  awk -v dest="$3" '
    $0 == "# BEGIN aw1cks cache provisioning" {
      if (seen || state) { bad=1; exit 1 }; seen=1; state=1; next
    }
    $0 == "# END aw1cks cache provisioning" {
      if (state != 2) { bad=1; exit 1 }; state=0; ended=1; next
    }
    state == 1 {
      if ($0 != "include " dest) { bad=1; exit 1 }; state=2; next
    }
    state == 2 || index($0, "aw1cks-caches.conf") { bad=1; exit 1 }
    ended && $0 !~ /^[[:space:]]*(#.*)?$/ { bad=1; exit 1 }
    { print }
    END {
      if (bad || state) exit 1
      print "# BEGIN aw1cks cache provisioning"
      print "include " dest
      print "# END aw1cks cache provisioning"
    }
  ' "$1" > "$2" || { cache_error 'Conflicting/partial include block; no files changed.'; return 1; }
}

cache_validation_file() {
  # Preserve the original base directory of other relative includes in the
  # temporary validation config. Never rewrite those admin-owned include files.
  awk -v base="$3" -v dest="$4" -v candidate="$5" '
    $1 == "include" || $1 == "!include" {
      if (NF > 2 && $3 !~ /^#/) exit 1
      path=$2
      if (path == dest) path=candidate
      else if (substr(path, 1, 1) != "/") path=base "/" path
      print $1 " " path
      next
    }
    { print }
  ' "$1" > "$2"
}

cache_parse() {
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null NIX_CONF_DIR="$1" \
    "$cache_nix" --extra-experimental-features nix-command config show > "$2" 2> "$3"
}
cache_ping() {
  NIX_CONFIG='' NIX_USER_CONF_FILES=/dev/null NIX_REMOTE=daemon \
    "$cache_nix" --extra-experimental-features nix-command --store daemon store ping >/dev/null
}
cache_restart() {
  case "$cache_service" in
    systemd) systemctl restart nix-daemon.service ;;
    launchd) launchctl kickstart -k system/org.nixos.nix-daemon ;;
    *) cache_error 'Unsupported service manager.'; return 1 ;;
  esac
}
cache_wait() {
  attempt=0
  while [ "$attempt" -lt 5 ]; do
    cache_ping && return 0
    attempt=$((attempt + 1))
    sleep 1
  done
  cache_error 'Daemon did not become reachable.'
}

cache_transaction() (
  # Subshell: traps and temporary state cannot leak to the caller.
  set -eu
  set -f
  umask 077
  directory=$1
  main="$directory/nix.conf"
  dest="$directory/aw1cks-caches.conf"
  lock="$directory/.aw1cks-caches.lock"
  cache_secure "$directory"
  [ -f "$main" ] || { cache_error "Missing $main; install Lix first."; exit 1; }
  cache_secure "$main"
  if grep -Eiq '^[[:space:]]*#.*(NixOS|nix-darwin|Determinate|generated from.*nix.settings)' "$main"; then
    cache_error 'Main configuration has a declarative/external owner; refusing to edit it.'; exit 1
  fi
  old_fragment=false
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    cache_secure "$dest"
    [ -f "$dest" ] || { cache_error 'Fragment is not a regular file.'; exit 1; }
    cache_fragment_valid "$dest"
    old_fragment=true
  fi
  mkdir "$lock" || { cache_error "Another sync holds $lock (or a prior run was interrupted); inspect before removing it."; exit 1; }
  txn=''; changed=false; committed=false; rotation=false
  cleanup() {
    result=$?
    trap - 0 HUP INT TERM
    if [ "$changed" = true ] && [ "$committed" = false ]; then
      if [ "$rotation" = true ]; then
        printf 'cache-provision: FAILED after a key/cache removal. New policy retained; refusing to restore retired trust. Backups: %s\n' "$txn" >&2
      else
        # Restore main first, so an include never points to a deleted fragment.
        if cp -p "$txn/main.before" "$txn/main.rollback" && mv -f "$txn/main.rollback" "$main"; then
          if [ "$old_fragment" = true ]; then
            cp -p "$txn/fragment.before" "$txn/fragment.rollback" && mv -f "$txn/fragment.rollback" "$dest" || result=1
          else
            rm -f "$dest" || result=1
          fi
          cache_restart && cache_wait || printf '%s\n' 'cache-provision: old files restored, but daemon recovery failed; administrator action required.' >&2
        else
          printf 'cache-provision: rollback FAILED; restore root-only backups at %s\n' "$txn" >&2
        fi
      fi
      result=1
    fi
    if [ -n "$txn" ]; then
      # Do not retain the expanded parser output (may contain admin credentials).
      rm -rf "$txn/check" "$txn/effective" "$txn/parser.err"
      if [ "$changed" = true ]; then
        printf 'cache-provision: root-only transaction/backups: %s\n' "$txn" >&2
      else
        rm -rf "$txn"
      fi
    fi
    rmdir "$lock" || result=1
    exit "$result"
  }
  trap cleanup 0
  trap 'exit 1' HUP INT TERM
  txn=$(mktemp -d "$directory/.aw1cks-caches.XXXXXX")
  cp -p "$main" "$txn/main.before"
  [ "$old_fragment" = false ] || cp -p "$dest" "$txn/fragment.before"
  cat > "$txn/fragment.new"
  cache_fragment_valid "$txn/fragment.new"
  cp -p "$main" "$txn/main.new"
  cache_main_candidate "$main" "$txn/main.new" "$dest"
  mkdir "$txn/check"
  cache_validation_file "$txn/main.new" "$txn/check/nix.conf" "$directory" "$dest" "$txn/fragment.new"
  cache_parse "$txn/check" "$txn/effective" "$txn/parser.err" || {
    cat "$txn/parser.err" >&2; cache_error 'Candidate configuration does not parse.'; exit 1;
  }
  if grep -Eiq 'warning:|error:' "$txn/parser.err"; then
    cat "$txn/parser.err" >&2; cache_error 'Parser warnings are not accepted for provisioning.'; exit 1
  fi
  [ "$(cache_values "$txn/effective" require-sigs)" = true ] || {
    cache_error 'Signature verification is disabled; fix daemon policy before provisioning.'; exit 1;
  }
  for setting in substituters trusted-public-keys; do
    cache_values "$txn/fragment.new" "extra-$setting" > "$txn/new.tokens"
    cache_values "$txn/effective" "$setting" > "$txn/effective.tokens"
    while IFS= read -r token; do
      grep -Fxq "$token" "$txn/effective.tokens" || {
        cache_error "Candidate lost expected $setting entry: $token"; exit 1;
      }
    done < "$txn/new.tokens"
    if [ "$old_fragment" = true ]; then
      cache_values "$txn/fragment.before" "extra-$setting" > "$txn/old.tokens"
      while IFS= read -r token; do
        if ! grep -Fxq "$token" "$txn/new.tokens"; then
          rotation=true
          if grep -Fxq "$token" "$txn/effective.tokens"; then
            cache_error "Retired $setting entry also exists outside the owned fragment: $token"; exit 1
          fi
        fi
      done < "$txn/old.tokens"
    fi
  done
  cmp -s "$main" "$txn/main.before" || { cache_error 'Main config changed during validation; retry.'; exit 1; }
  if [ "$old_fragment" = true ]; then
    cmp -s "$dest" "$txn/fragment.before" || { cache_error 'Fragment changed during validation; retry.'; exit 1; }
  else
    [ ! -e "$dest" ] && [ ! -L "$dest" ] || { cache_error 'Fragment appeared during validation; retry.'; exit 1; }
  fi
  chmod 644 "$txn/fragment.new"
  # root's primary group is appropriate on Linux and macOS (normally root/wheel).
  chown 0 "${txn}/fragment.new"
  changed=true
  mv -f "$txn/fragment.new" "$dest"
  mv -f "$txn/main.new" "$main"
  cache_restart
  cache_wait
  committed=true
  printf '%s\n' 'cache-provision: file installed, include validated, daemon restarted and reachable.'
  printf '%s\n' 'cache-provision: this does NOT verify cache coverage or ordinary-user substitution.'
)
