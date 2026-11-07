# Keep the caller's NIX_CONFIG intact. First activation has its own explicit,
# narrowly scoped policy and does not require just to be installed.
set export

default:
  nix run .#default

rebuild target=".":
  nix run .#rebuild -- {{quote(target)}}

fix-nix-daemon:
  @set -e; \
  if [ "$(uname -s)" != "Darwin" ]; then echo "fix-nix-daemon is only supported on macOS"; exit 1; fi; \
  if ! launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1 && nix store ping --store daemon >/dev/null 2>&1; then echo "nix-daemon is responding via a manual process; stopping here to avoid breaking the current session"; exit 1; fi; \
  if nix store ping --store daemon >/dev/null 2>&1; then echo "nix-daemon is already responding"; exit 0; fi; \
  sudo launchctl bootout system/org.nixos.nix-daemon >/dev/null 2>&1 || true; \
  sudo rm -f /nix/var/nix/daemon-socket/socket; \
  sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist; \
  sudo launchctl enable system/org.nixos.nix-daemon; \
  sudo launchctl kickstart -k system/org.nixos.nix-daemon; \
  if nix store ping --store daemon >/dev/null 2>&1; then echo "nix-daemon recovered"; else echo "launchd did not recover nix-daemon; a reboot is likely required"; exit 1; fi

# Explicit owner: nixos, darwin, or standalone-hm. No flake app is built first.
bootstrap owner target:
  python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py bootstrap {{quote(owner)}} {{quote(target)}}

# Compatibility name now requires an owner and target instead of writing conf.d.
bootstrap-cache owner target: (bootstrap owner target)

# Official-cache-only first switch for a broken inherited cache configuration.
recover owner target:
  python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py --recovery bootstrap {{quote(owner)}} {{quote(target)}}

# Standalone daemon only; never run as a Home Manager activation hook.
sync-caches:
  python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py sync-caches

check-caches:
  python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py check-caches

probe-cache store_path:
  python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py probe {{quote(store_path)}}

[positional-arguments]
update *args:
  nix run .#update -- "$@"

gc days="7":
  nix run .#clean -- --gc-only {{quote(days)}}

optimise:
  nix run .#clean -- --optimise-only

clean days="7":
  nix run .#clean -- {{quote(days)}}
