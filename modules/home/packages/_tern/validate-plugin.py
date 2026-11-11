"""Validate native Tern plugin packages without executing their code."""

import argparse
from pathlib import Path
import re
import sys
import tomllib


class InvalidPlugin(ValueError):
    pass


def contained_file(source: Path, value: object, field: str) -> Path:
    if not isinstance(value, str) or not value.strip():
        raise InvalidPlugin(f"{field} must be a nonempty relative file path")
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise InvalidPlugin(f"{field} must stay within the source directory: {value!r}")
    try:
        resolved = (source / relative).resolve(strict=True)
    except (OSError, RuntimeError, ValueError) as error:
        raise InvalidPlugin(f"{field} cannot resolve {value!r}: {error}") from error
    if not resolved.is_relative_to(source):
        raise InvalidPlugin(f"{field} escapes the source directory: {value!r}")
    if not resolved.is_file():
        raise InvalidPlugin(f"{field} must name a regular file: {value!r}")
    return resolved


def validate(source: Path, plugin_id: str) -> None:
    if re.fullmatch(r"[a-z0-9-]{1,32}", plugin_id) is None or plugin_id == "tern":
        raise InvalidPlugin("id must be 1–32 lowercase letters, digits or hyphens; tern is reserved")
    source = source.resolve(strict=True)
    if not source.is_dir():
        raise InvalidPlugin(f"source is not a directory: {source}")
    manifest = contained_file(source, "plugin.toml", "plugin.toml")
    if manifest.stat().st_size > 64 * 1024:
        raise InvalidPlugin("plugin.toml is larger than 64 KiB")
    with manifest.open("rb") as handle:
        data = tomllib.load(handle)
    if type(data.get("schema")) is not int or data["schema"] != 1:
        raise InvalidPlugin("plugin.toml schema must be integer 1")
    if data.get("id") != plugin_id:
        raise InvalidPlugin(f"plugin.toml id must match registry key {plugin_id!r}; got {data.get('id')!r}")
    if not isinstance(data.get("version"), str):
        raise InvalidPlugin("plugin.toml version must be a string")
    if not isinstance(data.get("name"), str) or not 1 <= len(data["name"]) <= 64:
        raise InvalidPlugin("plugin.toml name must be 1–64 characters")
    if "host" not in data and "window" not in data:
        raise InvalidPlugin("plugin.toml needs a host or window entry")
    for field in ("host", "window"):
        if field in data:
            contained_file(source, data[field], field)
            if Path(data[field]).suffix not in (".luau", ".lua"):
                raise InvalidPlugin(f"{field} must be a .luau or .lua file: {data[field]!r}")
    styles = data.get("styles", [])
    if not isinstance(styles, list):
        raise InvalidPlugin("plugin.toml styles must be an array of relative file paths")
    style_bytes = 0
    for index, value in enumerate(styles):
        style_bytes += contained_file(source, value, f"styles[{index}]").stat().st_size
    if style_bytes > 256 * 1024:
        raise InvalidPlugin("plugin.toml styles are larger than 256 KiB")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", required=True, dest="plugin_id")
    parser.add_argument("--source", required=True, type=Path)
    args = parser.parse_args()
    try:
        validate(args.source, args.plugin_id)
    except (InvalidPlugin, OSError, RuntimeError, ValueError) as error:
        print(f"Tern plugin {args.plugin_id!r}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
