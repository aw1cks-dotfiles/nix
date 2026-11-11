"""Prepare mutable, private Kata state without replacing existing credentials."""

import argparse
import errno
import os
import secrets
import stat
import sys


MAX_TOKEN_BYTES = 65536


def _checked_file(directory_fd: int, name: str, *, token: bool) -> None:
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory_fd)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError(f"{name} must be an owned regular non-symlink file")
        if info.st_mode & 0o077:
            raise ValueError(f"{name} must have private permissions")
        if token:
            if info.st_size > MAX_TOKEN_BYTES:
                raise ValueError("auth-token exceeds the size limit")
            # Bound the read even if another process grows the file concurrently.
            with os.fdopen(os.dup(fd), "rb") as source:
                value = source.read(MAX_TOKEN_BYTES + 1)
            if len(value) > MAX_TOKEN_BYTES:
                raise ValueError("auth-token exceeds the size limit")
            try:
                text = value.decode("utf-8")
            except UnicodeDecodeError:
                raise ValueError("auth-token must contain UTF-8 text") from None
            if not text.strip() or "\x00" in text:
                raise ValueError("auth-token must contain nonempty text")
        os.fchmod(fd, 0o600)
    finally:
        os.close(fd)


def _create_file(directory_fd: int, name: str, contents: bytes) -> None:
    temporary = f".kata-private-{secrets.token_hex(16)}"
    fd = os.open(
        temporary,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
        dir_fd=directory_fd,
    )
    try:
        with os.fdopen(fd, "wb") as target:
            target.write(contents)
            target.flush()
            os.fchmod(target.fileno(), 0o600)
            os.fsync(target.fileno())
        # Hard linking publishes a complete file atomically and never replaces
        # a credential created by another launcher in the meantime.
        try:
            os.link(
                temporary,
                name,
                src_dir_fd=directory_fd,
                dst_dir_fd=directory_fd,
                follow_symlinks=False,
            )
        except FileExistsError:
            pass
    finally:
        os.unlink(temporary, dir_fd=directory_fd)


def prepare_state(state: str, *, log: bool = False) -> None:
    """Prepare state/auth-token; optionally prepare daemon.log for launchd."""
    if not os.path.isabs(state) or ".." in state.split("/"):
        raise ValueError("state must be an absolute path without parent components")
    state = os.path.normpath(state)
    resolved = os.path.realpath(state)
    if state == "/" or resolved == "/":
        raise ValueError("state must not be the filesystem root")
    if any(path == "/nix/store" or path.startswith("/nix/store/") for path in (state, resolved)):
        raise ValueError("state must be outside the Nix store")
    # Use mkdir for the final component so an existing symlink is not followed.
    os.makedirs(os.path.dirname(state), mode=0o700, exist_ok=True)
    try:
        os.mkdir(state, mode=0o700)
    except FileExistsError:
        pass
    directory_fd = os.open(state, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = os.fstat(directory_fd)
        if info.st_uid != os.getuid():
            raise ValueError("state directory must be owned by the current user")
        os.fchmod(directory_fd, 0o700)
        try:
            _checked_file(directory_fd, "auth-token", token=True)
        except FileNotFoundError:
            _create_file(directory_fd, "auth-token", (secrets.token_urlsafe(32) + "\n").encode("ascii"))
            _checked_file(directory_fd, "auth-token", token=True)
        if log:
            try:
                _checked_file(directory_fd, "daemon.log", token=False)
            except FileNotFoundError:
                _create_file(directory_fd, "daemon.log", b"")
                _checked_file(directory_fd, "daemon.log", token=False)
    finally:
        os.close(directory_fd)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True)
    parser.add_argument("--log", action="store_true", help="also prepare private daemon.log")
    args = parser.parse_args()
    try:
        prepare_state(args.state, log=args.log)
    except (OSError, ValueError) as error:
        # Do not include file contents, including tokens, in diagnostics.
        if isinstance(error, OSError):
            message = os.strerror(error.errno or errno.EIO)
        else:
            message = str(error)
        print(f"Kata state preparation failed: {message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
