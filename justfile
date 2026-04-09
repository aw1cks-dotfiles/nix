is_wsl := path_exists("/proc/sys/fs/binfmt_misc/WSLInterop")
is_nixos := path_exists("/run/current-system/nixos-version")

rebuild_command := if os() == "macos" {
  "nix run .#nh -- darwin switch"
} else if os() == "linux" {
  if is_wsl == "true" {
    error("WSL is not supported yet")
  } else if is_nixos == "true" {
    "nix run .#nh -- os switch"
  } else {
    "nix run .#nh -- home switch"
  }
} else {
  error("Unsupported OS: " + os())
}

default:
  @just --list --unsorted

rebuild target=".":
  {{rebuild_command}} {{target}}

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

update:
  nix flake update

nix_sudo := if os() == "macos" { "sudo -H nix" } else { "nix" }
gc_command := if os() == "macos" {
  "sudo -H nix-env --profile /nix/var/nix/profiles/system --delete-generations"
} else {
  "nix profile wipe-history" 
}
gc_day0_value := if os() == "macos" { "old" } else { "" }

gc days="7":
  {{gc_command}} \
    {{ if days == "0" { gc_day0_value } else { if os() == "macos" {"+" + days} else {"--older-than " + days + "d"} } }}
  {{nix_sudo}} store gc

optimise:
  {{nix_sudo}} store optimise

clean days="7": (gc days) optimise
