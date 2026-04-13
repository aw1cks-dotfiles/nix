#!/bin/sh
# Wrapper script that provides the `mmdc` interface expected by Snacks.image,
# but uses `mmdr` under the hood.
# `mmdc` depends on Chromium which often gets built from source, causing a heavy closure.
# it's also much slower than `mmdr` which is a pure Rust implementation.

if [ "$#" -eq 1 ] && [ "$1" = "--version" ]; then
  printf 'mmdc (mmdr wrapper)\n'
  exit 0
fi

input=
output=
theme=neutral
scale=1

while [ "$#" -gt 0 ]; do
  case "$1" in
  -i | --input)
    input="$2"
    shift 2
    ;;
  -o | --output)
    output="$2"
    shift 2
    ;;
  -t | --theme)
    theme="$2"
    shift 2
    ;;
  -s | --scale)
    scale="$2"
    shift 2
    ;;
  -b | --background)
    shift 2
    ;;
  -q | --quiet)
    shift
    ;;
  -h | --help)
    printf 'mmdc compatibility wrapper for Snacks.image\n'
    exit 0
    ;;
  *)
    printf 'Unsupported mmdc argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

if [ -z "$input" ] || [ -z "$output" ]; then
  printf 'mmdc wrapper requires -i <input> and -o <output>\n' >&2
  exit 2
fi

config="@mmdrLightConfig@"
if [ "$theme" = "dark" ]; then
  config="@mmdrDarkConfig@"
fi

width="$(awk -v scale="$scale" 'BEGIN { printf "%d", 1200 * scale }')"
height="$(awk -v scale="$scale" 'BEGIN { printf "%d", 800 * scale }')"

exec @mmdrBin@ \
  -i "$input" \
  -o "$output" \
  -e png \
  -c "$config" \
  -w "$width" \
  -H "$height"
