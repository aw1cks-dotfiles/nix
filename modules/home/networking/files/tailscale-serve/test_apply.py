"""Safety/lifecycle regressions; actual whole-state replacement is smoke-tested."""

import copy
import json
from pathlib import Path
import stat
import tempfile
import unittest

import apply as subject

HOST = "mbp.gentoo-boa.ts.net"
DESIRED = {
    "TCP": {"443": {"HTTPS": True}},
    "Web": {f"{HOST}:443": {"Handlers": {"/": {"Proxy": "http://127.0.0.1:7467"}}}},
}


class Backend:
    def __init__(self, current=None):
        self.current = copy.deepcopy(current)
        self.node = {"BackendState": "Running", "Self": {"DNSName": HOST.upper() + "."}}
        self.writes = 0
        self.after_read = None
        self.before_write = None
        self.fail_write = False

    def status(self):
        return copy.deepcopy(self.node)

    def config(self):
        if self.after_read:
            self.after_read()
        return copy.deepcopy(self.current)

    def apply(self, value):
        if self.before_write:
            self.before_write()
        if self.fail_write:
            raise subject.ApplyError("backend unavailable")
        self.writes += 1
        self.current = copy.deepcopy(value)


class ApplyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.marker = root / "state" / "managed.json"
        self.config = root / "desired.json"
        self.config.write_text(json.dumps(DESIRED))
        self.options = {
            "tailscale": "/installed/tailscale",
            "hostname": HOST,
            "markerFile": str(self.marker),
            "configFile": str(self.config),
            "enabled": True,
        }

    def seed(self, host=HOST):
        self.marker.parent.mkdir(mode=0o700)
        self.marker.write_text(json.dumps({"version": 1, "hostname": host}))

    def disable(self, client):
        subject.apply(dict(self.options, enabled=False, hostname=""), client)

    def test_matching_state_records_private_marker_without_reload(self):
        backend = Backend(DESIRED)
        subject.apply(self.options, backend)
        subject.apply(self.options, backend)
        self.assertEqual(backend.writes, 0)
        self.assertEqual(
            json.loads(self.marker.read_text()), {"version": 1, "hostname": HOST}
        )
        self.assertEqual(stat.S_IMODE(self.marker.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.marker.parent.stat().st_mode), 0o700)

    def test_null_state_matches_empty_declaration_without_reload(self):
        self.config.write_text("{}")
        backend = Backend(None)
        subject.apply(self.options, backend)
        self.assertEqual(backend.writes, 0)
        self.assertTrue(self.marker.exists())

    def test_wrong_identity_or_offline_backend_cannot_apply_or_mark(self):
        for node in (
            {"BackendState": "Running", "Self": {"DNSName": "other.example.net"}},
            {"BackendState": "Stopped"},
        ):
            with self.subTest(node=node):
                backend = Backend()
                backend.node = node
                with self.assertRaises(subject.ApplyError):
                    subject.apply(self.options, backend)
                self.assertEqual(backend.writes, 0)
                self.assertFalse(self.marker.exists())

    def test_profile_switch_during_read_cannot_mark_or_apply(self):
        backend = Backend()
        backend.after_read = lambda: backend.node["Self"].update(
            DNSName="other.example.net"
        )
        with self.assertRaises(subject.ApplyError):
            subject.apply(self.options, backend)
        self.assertEqual(backend.writes, 0)
        self.assertFalse(self.marker.exists())

    def test_failed_write_retains_marker_for_retry(self):
        backend = Backend()
        backend.fail_write = True
        backend.before_write = lambda: self.assertTrue(self.marker.exists())
        with self.assertRaises(subject.ApplyError):
            subject.apply(self.options, backend)
        self.assertTrue(self.marker.exists())
        backend.fail_write = False
        subject.apply(self.options, backend)
        self.assertTrue(self.marker.exists())

    def test_never_enabled_disable_does_not_touch_backend_or_state(self):
        self.config.unlink()
        self.disable(object())
        self.assertFalse(self.marker.parent.exists())

    def test_cleanup_removes_marker_only_after_successful_clear(self):
        self.seed()
        backend = Backend(DESIRED)
        backend.fail_write = True
        with self.assertRaises(subject.ApplyError):
            self.disable(backend)
        self.assertTrue(self.marker.exists())
        backend.fail_write = False
        backend.before_write = lambda: self.assertTrue(self.marker.exists())
        self.disable(backend)
        self.assertFalse(self.marker.exists())

    def test_cleanup_profile_switch_keeps_marker_even_if_foreign_config_is_empty(self):
        self.seed()
        backend = Backend({})
        backend.after_read = lambda: backend.node["Self"].update(
            DNSName="other.example.net"
        )
        with self.assertRaises(subject.ApplyError):
            self.disable(backend)
        self.assertEqual(backend.writes, 0)
        self.assertTrue(self.marker.exists())

    def test_changed_declared_hostname_cannot_adopt_marker(self):
        self.seed("other.example.net")
        with self.assertRaises(subject.ApplyError):
            subject.apply(self.options, object())
        self.assertEqual(
            json.loads(self.marker.read_text())["hostname"], "other.example.net"
        )

    def test_unsafe_desired_config_cannot_reach_backend_or_create_marker(self):
        variants = [
            {**DESIRED, "AllowFunnel": {f"{HOST}:443": True}},
            {**DESIRED, "TCP": {"443": {"HTTP": True}}},
        ]
        for proxy in (
            "http://0.0.0.0:7467",
            "http://example.com:7467",
            "https://127.0.0.1:7467",
        ):
            value = copy.deepcopy(DESIRED)
            value["Web"][f"{HOST}:443"]["Handlers"]["/"]["Proxy"] = proxy
            variants.append(value)
        for value in variants:
            with self.subTest(value=value):
                self.config.write_text(json.dumps(value))
                with self.assertRaises(subject.ApplyError):
                    subject.apply(self.options, object())
                self.assertFalse(self.marker.exists())

    def test_symlink_marker_is_not_followed(self):
        self.marker.parent.mkdir()
        self.marker.symlink_to(self.config)
        with self.assertRaises(OSError):
            subject.apply(self.options, object())
        self.assertEqual(json.loads(self.config.read_text()), DESIRED)

    def test_unknown_marker_version_blocks_cleanup(self):
        self.seed()
        self.marker.write_text(json.dumps({"version": 2, "hostname": HOST}))
        with self.assertRaises(subject.ApplyError):
            self.disable(object())
        self.assertTrue(self.marker.exists())

    def test_protocol_transition_keeps_only_unblocked_declared_listeners(self):
        desired = copy.deepcopy(DESIRED)
        desired["TCP"]["8443"] = {"HTTPS": True}
        desired["Web"][f"{HOST}:8443"] = {
            "Handlers": {"/": {"Proxy": "http://127.0.0.1:7466"}}
        }
        live = {
            "TCP": {"443": {"HTTP": True}, "9999": {"TCPForward": "127.0.0.1:9999"}},
            "Services": {"svc:manual": {}},
            "AllowFunnel": {f"{HOST}:443": True},
        }
        staged = subject.transition_config(desired, live)
        self.assertEqual(set(staged["TCP"]), {"8443"})
        self.assertEqual(set(staged["Web"]), {f"{HOST}:8443"})
        self.assertEqual(set(staged), {"TCP", "Web"})
        self.assertEqual(set(desired["TCP"]), {"443", "8443"})

    def test_foreground_transition_can_require_an_empty_intermediate_config(self):
        live = {"Foreground": {"session": {"TCP": {"443": {"HTTPS": True}}}}}
        self.assertEqual(subject.transition_config(DESIRED, live), {})

    def test_existing_https_needs_no_intermediate_with_manual_paths(self):
        live = copy.deepcopy(DESIRED)
        live["Web"][f"{HOST}:443"]["Handlers"]["/manual"] = {"Text": "discard"}
        self.assertIsNone(subject.transition_config(DESIRED, live))


if __name__ == "__main__":
    unittest.main()
