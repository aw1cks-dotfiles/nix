"""Refuse managed Tern pointers that would leave duplicate native plugin IDs."""

import argparse
import os
from pathlib import Path
import re
import stat
import sys
import tomllib


MAX_MANIFEST_BYTES = 64 * 1024
MAX_POINTER_BYTES = 16 * 1024


class InspectionError(ValueError):
    pass


def read_regular(path: Path, limit: int) -> bytes | None:
    """Read bounded regular files only, without blocking on a special file."""
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except (FileNotFoundError, NotADirectoryError):
        return None
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        os.close(descriptor)
        return None
    with os.fdopen(descriptor, "rb") as handle:
        data = handle.read(limit + 1)
    if len(data) > limit:
        raise InspectionError(f"cannot safely inspect {path}: exceeds {limit} bytes")
    return data


def manifest_id(source: Path) -> str | None:
    try:
        data = read_regular(source / "plugin.toml", MAX_MANIFEST_BYTES)
    except InspectionError:
        # Native Tern rejects manifests larger than 64 KiB as non-packages.
        return None
    if data is None:
        return None
    try:
        manifest = tomllib.loads(data.decode("utf-8"))
    except (UnicodeError, tomllib.TOMLDecodeError):
        return None
    # Reject obvious non-packages, but do not lint user source or execute entries.
    # A parseable identity is conservatively guarded even if other package rules
    # could fail later in the native loader.
    if type(manifest.get("schema")) is not int or manifest["schema"] != 1:
        return None
    if not any(isinstance(manifest.get(field), str) and manifest[field] for field in ("host", "window")):
        return None
    plugin_id = manifest.get("id")
    if not isinstance(plugin_id, str) or re.fullmatch(r"[a-z0-9-]{1,32}", plugin_id) is None:
        return None
    return plugin_id


def check_collisions(root: Path, selected_ids: list[str]) -> None:
    if not selected_ids:
        return
    selected = set(selected_ids)
    managed_slots = {f"{plugin_id}.path" for plugin_id in selected}
    try:
        entries = sorted(root.iterdir(), key=lambda entry: entry.name)
    except FileNotFoundError:
        return
    except OSError as error:
        raise InspectionError(f"cannot inspect plugin root {root}: {error}") from error
    for entry in entries:
        if entry.name.startswith(".") or entry.name in managed_slots:
            continue
        try:
            try:
                mode = entry.stat().st_mode
            except FileNotFoundError:
                continue
            if stat.S_ISDIR(mode):
                source = entry
            elif entry.suffix == ".path" and stat.S_ISREG(mode):
                pointer = read_regular(entry, MAX_POINTER_BYTES)
                if pointer is None:
                    continue
                try:
                    target = pointer.decode("utf-8").strip()
                except UnicodeError:
                    continue
                if not target or "\x00" in target:
                    continue
                source = Path(target)
                if not source.is_absolute():
                    continue
            else:
                continue
            plugin_id = manifest_id(source)
        except (OSError, InspectionError) as error:
            raise InspectionError(
                f"cannot inspect {entry} for managed plugin IDs {', '.join(sorted(selected))}: {error}. "
                "No plugin source or data was changed. Resolve inspection access before activation."
            ) from error
        if plugin_id in selected:
            raise InspectionError(
                f"Tern plugin migration required: ID {plugin_id!r} in {entry} conflicts with "
                f"managed pointer {root / (plugin_id + '.path')}. Explicitly move the old source "
                "outside the plugin root (and move any alias pointer outside it) before activation. "
                "Plugin data is retained; no source, pointer or data was changed."
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--id", action="append", default=[], dest="selected_ids")
    args = parser.parse_args()
    try:
        check_collisions(args.root, args.selected_ids)
    except InspectionError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
