#!/bin/sh
set -eu

if ! command -v zramctl >/dev/null 2>&1; then
  echo "bootstrap-pre-kexec: zramctl not available on target host" >&2
  exit 1
fi

if ! command -v mkswap >/dev/null 2>&1 || ! command -v swapon >/dev/null 2>&1; then
  echo "bootstrap-pre-kexec: mkswap/swapon not available on target host" >&2
  exit 1
fi

if swapon --show=NAME --noheadings 2>/dev/null | grep -Eq '^/dev/zram'; then
  echo "bootstrap-pre-kexec: zram swap already active" >&2
  exit 0
fi

if command -v modprobe >/dev/null 2>&1; then
  modprobe zram || true
fi

mem_total_kb="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)"
if [ -z "$mem_total_kb" ]; then
  echo "bootstrap-pre-kexec: failed to detect MemTotal from /proc/meminfo" >&2
  exit 1
fi

zram_size_bytes=$((mem_total_kb * 1024 / 2))
if [ "$zram_size_bytes" -lt $((256 * 1024 * 1024)) ]; then
  zram_size_bytes=$((256 * 1024 * 1024))
fi

zram_device="$(zramctl --find --size "$zram_size_bytes" --algorithm zstd)"
if [ -z "$zram_device" ]; then
  echo "bootstrap-pre-kexec: failed to create zram device" >&2
  exit 1
fi

mkswap "$zram_device" >/dev/null
swapon --priority 100 "$zram_device"

echo "bootstrap-pre-kexec: enabled $zram_device as zram swap for nixos-anywhere kexec" >&2
