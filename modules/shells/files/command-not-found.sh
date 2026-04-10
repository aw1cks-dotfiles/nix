#!/bin/sh
# This file is sourced by both Bash and Zsh command-not-found hooks, so keep
# it POSIX-sh compatible even though it is not executed directly.
# shellcheck shell=sh

__dendritic_command_not_found() {
  cmd="$1"
  attrs=""
  attr_count=0

  if [ -n "${MC_SID-}" ] || ! [ -t 1 ]; then
    printf '%s: command not found\n' "$cmd" >&2
    return 127
  fi

  attrs="$(@nixLocate@ --minimal --no-group --type x --type s --whole-name --at-root "/bin/$cmd")"

  if [ -z "$attrs" ]; then
    printf '%s: command not found\n' "$cmd" >&2
    return 127
  fi

  attr_count=$(printf '%s\n' "$attrs" | grep -c '^')

  if [ "$attr_count" -eq 1 ]; then
    printf "The program '%s' is currently not installed.\n" "$cmd" >&2
    printf '\nIt was found in nixpkgs:\n' >&2
    printf '  nixpkgs#%s\n\n' "$attrs" >&2
    printf 'Run it ad-hoc with:\n' >&2
    printf '  nix shell nixpkgs#%s -c %s ...\n' "$attrs" "$cmd" >&2
  else
    printf "The program '%s' is currently not installed.\n" "$cmd" >&2
    printf '\nIt was found in multiple nixpkgs packages:\n' >&2
    printf '%s\n' "$attrs" | while IFS= read -r attr; do
      printf '  nixpkgs#%s\n' "$attr" >&2
    done

    printf '\nRun one ad-hoc with:\n' >&2
    printf '%s\n' "$attrs" | while IFS= read -r attr; do
      printf '  nix shell nixpkgs#%s -c %s ...\n' "$attr" "$cmd" >&2
    done
  fi

  return 127
}
