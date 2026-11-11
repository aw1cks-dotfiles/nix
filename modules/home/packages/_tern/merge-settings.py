#!/usr/bin/env python3
"""Reconcile mutable Tern settings with declarative, leaf-level ownership.

Objects merge recursively; arrays and scalars are owned as whole leaves. An
explicit empty object ensures an object exists without owning its custom children.
Removed managed paths prune empty ancestor objects, not unrelated empty objects.

State is a private versioned journal, not a copy of settings. Before replacing
settings, record previous/new ownership and hashes of before/after settings.
After replacing settings, compact to desired ownership. Recovery selects the
ownership matching the settings hash, even with a different next declaration.
If settings were externally edited during an interrupted commit, recovery fails
closed rather than guessing ownership. Each replacement is atomic, not the pair:
an I/O failure can leave pending state or already-updated settings. Invalid input
never writes anything. Concurrent writers/activations are not coordinated; run
while no other process is writing settings to avoid lost updates.

Output parents must already exist. Output symlinks/nonregular files are refused;
replacement is relative to an open parent directory and never follows a leaf
symlink. Existing parent-directory symlinks are resolved when opening that parent.
"""

import argparse
from contextlib import ExitStack
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


class MergeError(Exception):
    """An input or filesystem condition makes reconciliation unsafe."""


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise MergeError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def _constant(value):
    raise MergeError(f"invalid JSON constant: {value}")


def _decode(data, label):
    try:
        value = json.loads(data, object_pairs_hook=_object, parse_constant=_constant)
    except (ValueError, UnicodeError) as error:
        raise MergeError(f"invalid JSON in {label}: {error}") from error
    if not isinstance(value, dict):
        raise MergeError(f"{label} must contain a JSON object")
    return value


def _read_output(directory, name):
    try:
        descriptor = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                             dir_fd=directory)
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        os.close(descriptor)
        raise MergeError(f"{name} must be a regular file, not a symlink")
    with os.fdopen(descriptor, "rb") as stream:
        return stream.read()


def _remove_owned(current, owned):
    """Remove owned leaves in place, retaining custom siblings and their shells."""
    for key, value in owned.items():
        if key not in current:
            continue
        if isinstance(value, dict):
            if isinstance(current[key], dict):
                _remove_owned(current[key], value)
                if not current[key]:
                    del current[key]
        else:
            del current[key]


def _overlay(current, desired):
    for key, value in desired.items():
        if isinstance(value, dict):
            if not isinstance(current.get(key), dict):
                current[key] = {}
            _overlay(current[key], value)
        else:
            current[key] = deepcopy(value)


def reconcile(current, owned, desired):
    """Return reconciled settings without mutating any input."""
    result = deepcopy(current)
    _remove_owned(result, owned)
    _overlay(result, desired)
    return result


def _digest(data):
    return None if data is None else hashlib.sha256(data).hexdigest()


def _restrict_permissions(directory, name):
    try:
        descriptor = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                             dir_fd=directory)
    except FileNotFoundError:
        return
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise MergeError(f"{name} must be a regular file, not a symlink")
        if stat.S_IMODE(metadata.st_mode) != 0o600:
            os.fchmod(descriptor, 0o600)
    finally:
        os.close(descriptor)


def _ownership(state, settings_data):
    if state is None:
        return {}
    if (set(state) not in ({"version", "managed"}, {"version", "managed", "pending"})
            or type(state["version"]) is not int or state["version"] != 1
            or not isinstance(state["managed"], dict)):
        raise MergeError("unsupported or invalid ownership state")
    if "pending" not in state:
        return state["managed"]
    pending = state["pending"]
    if (not isinstance(pending, dict)
            or set(pending) != {"managed", "before", "after"}
            or not isinstance(pending["managed"], dict)
            or not all(value is None or (isinstance(value, str) and len(value) == 64
                       and all(char in "0123456789abcdef" for char in value))
                       for value in (pending["before"], pending["after"]))
            or pending["after"] is None):
        raise MergeError("invalid pending ownership state")
    digest = _digest(settings_data)
    if digest == pending["after"]:
        return pending["managed"]
    if digest == pending["before"]:
        return state["managed"]
    raise MergeError("settings changed during an interrupted merge; cannot infer ownership")


def _encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)
            + "\n").encode("utf-8")


def _replace(directory, parent, name, data):
    # The temp file is private from creation, including if writing/fsync fails.
    descriptor, temporary = tempfile.mkstemp(prefix=f".{name}.", dir=parent)
    temporary_name = Path(temporary).name
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            metadata = os.stat(name, dir_fd=directory, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            if not stat.S_ISREG(metadata.st_mode):
                raise MergeError(f"{name} must be a regular file, not a symlink")
        os.replace(temporary_name, name, src_dir_fd=directory, dst_dir_fd=directory)
        os.fsync(directory)
    finally:
        try:
            os.unlink(temporary_name, dir_fd=directory)
        except FileNotFoundError:
            pass


def merge_settings(settings, managed, state):
    """Apply one declaration; return whether settings content was replaced.

    All three paths must be distinct. Missing settings/state mean empty settings
    and no previous ownership. Malformed input, including state, fails closed.
    """
    settings, managed, state = (Path(path).absolute() for path in (settings, managed, state))
    # Resolve parents, not leaves: resolving a leaf would follow an output symlink.
    settings = settings.parent.resolve(strict=True) / settings.name
    state = state.parent.resolve(strict=True) / state.name
    if len({settings, managed.resolve(), state}) != 3:
        raise MergeError("settings, managed and state paths must be distinct")
    with ExitStack() as stack:
        directories = []
        for path in (settings, state):
            descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            stack.callback(os.close, descriptor)
            directories.append(descriptor)
        settings_dir, state_dir = directories
        settings_data = _read_output(settings_dir, settings.name)
        state_data = _read_output(state_dir, state.name)
        desired = _decode(managed.read_bytes(), managed)
        current = {} if settings_data is None else _decode(settings_data, settings)
        previous = None if state_data is None else _decode(state_data, state)
        owned = _ownership(previous, settings_data)
        result = reconcile(current, owned, desired)
        # Encode everything before the first write; e.g. invalid Unicode must not
        # leave even an ownership journal behind.
        settings_bytes = _encode(result)
        journal = {"version": 1, "managed": owned, "pending": {
            "managed": desired, "before": _digest(settings_data),
            "after": _digest(settings_bytes),
        }}
        final = {"version": 1, "managed": desired}
        journal_bytes, final_bytes = _encode(journal), _encode(final)
        changed = settings_data is None or json.dumps(current, sort_keys=True) != json.dumps(
            result, sort_keys=True)
        _restrict_permissions(settings_dir, settings.name)
        _restrict_permissions(state_dir, state.name)
        if changed:
            if previous != journal:
                _replace(state_dir, state.parent, state.name, journal_bytes)
            _replace(settings_dir, settings.parent, settings.name, settings_bytes)
        if previous != final or (changed and journal != final):
            _replace(state_dir, state.parent, state.name, final_bytes)
        return changed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--settings", required=True, type=Path)
    parser.add_argument("--managed", required=True, type=Path)
    parser.add_argument("--state", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        merge_settings(args.settings, args.managed, args.state)
    except (MergeError, OSError, ValueError, UnicodeError) as error:
        print(f"tern settings merge: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
