is_wsl := path_exists("/proc/sys/fs/binfmt_misc/WSLInterop")
is_nixos := path_exists("/run/current-system/nixos-version")

rebuild_command := if os() == "macos" {
  "sudo -H --preserve-env=NIX_CONFIG nix run .#darwin --"
} else if os() == "linux" {
  if is_wsl == "true" {
    error("WSL is not supported yet")
  } else if is_nixos == "true" {
    "sudo --preserve-env=NIX_CONFIG nixos-rebuild"
  } else {
    "nix run .#home-manager --"
  }
} else {
  error("Unsupported OS: " + os())
}

default:
  @just --list --unsorted

rebuild target=".":
  {{rebuild_command}} switch --flake {{target}}

update:
  nix flake update

gc days="7":
  nix profile wipe-history {{ if days == "0" { "" } else { "--older-than " + days + "d" } }}
  nix store gc

optimise:
  nix store optimise

clean days="7": (gc days) optimise
