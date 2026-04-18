#!/usr/bin/env python3

import os
import select
import signal
import stat
import struct
import subprocess
from pathlib import Path

EVENT_DEVICE = "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse"
EVENT_TYPE_KEY = 1
PTT_KEY_CODE = 276
MUMBLE_SOCKET_NAME = "MumbleSocket"

_talking = False
_stop_requested = False


def _mumble_socket_path() -> Path | None:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime_dir:
        return None
    return Path(runtime_dir) / MUMBLE_SOCKET_NAME


def _mumble_available() -> bool:
    socket_path = _mumble_socket_path()
    if socket_path is None:
        return False
    try:
        mode = socket_path.stat().st_mode
    except FileNotFoundError:
        return False
    return stat.S_ISSOCK(mode)


def _rpc(command: str) -> bool:
    if not _mumble_available():
        return False

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "offscreen"
    result = subprocess.run(
        ["mumble", "rpc", command],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=env,
    )
    return result.returncode == 0


def _stop_talking() -> None:
    global _talking
    if _talking:
        _rpc("stoptalking")
        _talking = False


def _request_stop(*_args: object) -> None:
    global _stop_requested
    _stop_requested = True
    _stop_talking()


def main() -> int:
    global _talking

    signal.signal(signal.SIGINT, _request_stop)
    signal.signal(signal.SIGTERM, _request_stop)

    event_size = struct.calcsize("llHHI")

    with open(EVENT_DEVICE, "rb", buffering=0) as input_events:
        while not _stop_requested:
            readable, _, _ = select.select([input_events], [], [], 0.5)
            if not readable:
                continue

            event = input_events.read(event_size)
            if len(event) != event_size:
                continue

            _, _, event_type, code, value = struct.unpack("llHHI", event)
            if event_type != EVENT_TYPE_KEY or code != PTT_KEY_CODE:
                continue

            if value == 1 and not _talking:
                if _rpc("starttalking"):
                    _talking = True
            elif value == 0:
                _stop_talking()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
