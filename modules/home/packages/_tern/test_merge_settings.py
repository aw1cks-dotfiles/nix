"""Consumer-visible settings reconciliation and interrupted activation behavior."""

from contextlib import redirect_stderr
import importlib.util
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "merge_settings", Path(__file__).with_name("merge-settings.py")
)
subject = importlib.util.module_from_spec(spec)
spec.loader.exec_module(subject)


class MergeSettingsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.settings = self.root / "settings.json"
        self.managed = self.root / "managed.json"
        self.state = self.root / ".nix-settings-state.json"

    def declare(self, desired):
        self.managed.write_text(json.dumps(desired), encoding="utf-8")

    def apply(self, desired):
        self.declare(desired)
        return subject.merge_settings(self.settings, self.managed, self.state)

    def settings_value(self):
        return json.loads(self.settings.read_text(encoding="utf-8"))

    def test_custom_recents_and_keybindings_survive_managed_changes_and_removals(self):
        custom = {
            "recents": {"database": "/home/user/recents.sqlite", "limit": 50},
            "keybindings": {"ctrl+shift+x": "custom-command"},
            "appearance": {"fontSize": 15},
        }
        self.settings.write_text(json.dumps(custom))
        self.apply({"keybindings": {"ctrl+t": "new-tab"},
                    "appearance": {"theme": "dark"}, "obsolete": {"deep": True}})
        self.apply({"keybindings": {"ctrl+n": "new-window"},
                    "appearance": {"theme": "light"}})
        self.assertEqual(self.settings_value(), {
            **custom,
            "keybindings": {"ctrl+shift+x": "custom-command", "ctrl+n": "new-window"},
            "appearance": {"fontSize": 15, "theme": "light"},
        })
        self.apply({})
        self.assertEqual(self.settings_value(), custom)

    def test_runtime_custom_siblings_added_after_first_activation_survive(self):
        self.apply({"keybindings": {"ctrl+t": "new-tab"}, "nested": {"managed": 1}})
        value = self.settings_value()
        value["keybindings"]["ctrl+u"] = "user-command"
        value["nested"]["custom"] = {"keep": True}
        self.settings.write_text(json.dumps(value))
        self.apply({})
        self.assertEqual(self.settings_value(), {
            "keybindings": {"ctrl+u": "user-command"},
            "nested": {"custom": {"keep": True}},
        })

    def test_empty_objects_preserve_custom_children_and_remove_obsolete_shells(self):
        self.settings.write_text('{"unrelated": {}, "group": {"custom": 2}}')
        self.apply({"group": {}, "empty": {}, "nested": {"child": {"leaf": 1}}})
        self.assertEqual(self.settings_value(), {
            "unrelated": {}, "group": {"custom": 2}, "empty": {},
            "nested": {"child": {"leaf": 1}},
        })
        self.apply({})
        self.assertEqual(self.settings_value(), {"unrelated": {}, "group": {"custom": 2}})

    def test_managed_arrays_scalars_and_object_type_changes(self):
        self.apply({"value": {"old": 1}, "array": [1, 2]})
        self.apply({"value": "scalar", "array": [3]})
        self.assertEqual(self.settings_value(), {"value": "scalar", "array": [3]})
        self.apply({"value": {"new": None}})
        self.assertEqual(self.settings_value(), {"value": {"new": None}})
        self.apply({})
        self.assertEqual(self.settings_value(), {})

    def test_boolean_change_is_not_mistaken_for_equal_number(self):
        self.apply({"value": 1})
        self.assertTrue(self.apply({"value": True}))
        self.assertIs(self.settings_value()["value"], True)
        self.assertFalse(self.apply({"value": True}))

    def test_unchanged_files_get_private_permissions_without_replacement(self):
        self.apply({"theme": "dark"})
        before = {}
        for path in (self.settings, self.state):
            path.chmod(0o644)
            before[path] = (path.stat().st_ino, path.stat().st_mtime_ns)
        self.assertFalse(self.apply({"theme": "dark"}))
        for path in (self.settings, self.state):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual((path.stat().st_ino, path.stat().st_mtime_ns), before[path])

    def test_invalid_input_refuses_without_mutating_any_file(self):
        for target in ("settings", "managed", "state"):
            for invalid in ('{broken', '[]', 'null', '{"x": NaN}', '{"x": 1, "x": 2}'):
                with self.subTest(target=target, invalid=invalid):
                    self.apply({"theme": "dark"})
                    self.declare({"theme": "light"})
                    path = getattr(self, target)
                    valid = path.read_bytes()
                    path.write_text(invalid)
                    before = {item: (item.read_bytes(), item.stat().st_mtime_ns,
                                     item.stat().st_mode) for item in self.root.iterdir()}
                    with self.assertRaises(subject.MergeError):
                        subject.merge_settings(self.settings, self.managed, self.state)
                    after = {item: (item.read_bytes(), item.stat().st_mtime_ns,
                                    item.stat().st_mode) for item in self.root.iterdir()}
                    self.assertEqual(after, before)
                    path.write_bytes(valid)

    def test_invalid_state_schema_refuses_without_changing_settings(self):
        self.apply({"theme": "dark"})
        self.declare({"theme": "light"})
        for invalid in ({}, {"version": 2, "managed": {}},
                        {"version": 1, "managed": []},
                        {"version": 1, "managed": {}, "pending": {}}):
            with self.subTest(state=invalid):
                self.state.write_text(json.dumps(invalid))
                before = self.settings.read_bytes()
                with self.assertRaises(subject.MergeError):
                    subject.merge_settings(self.settings, self.managed, self.state)
                self.assertEqual(self.settings.read_bytes(), before)
                self.assertEqual(json.loads(self.state.read_text()), invalid)

    def test_unchanged_settings_are_not_rewritten_or_reformatted(self):
        self.apply({"theme": "dark"})
        self.settings.write_text('{ "custom": 7, "theme": "dark" }')
        before = self.settings.stat()
        state_before = self.state.stat()
        self.assertFalse(self.apply({"theme": "dark"}))
        after = self.settings.stat()
        self.assertEqual(self.settings.read_text(), '{ "custom": 7, "theme": "dark" }')
        self.assertEqual((after.st_ino, after.st_mtime_ns), (before.st_ino, before.st_mtime_ns))
        self.assertEqual(self.state.stat().st_mtime_ns, state_before.st_mtime_ns)

    def test_created_and_replaced_files_are_private(self):
        self.apply({"theme": "dark"})
        for path in (self.settings, self.state):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            path.chmod(0o644)
        self.apply({"theme": "light"})
        for path in (self.settings, self.state):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(set(self.root.iterdir()), {self.settings, self.managed, self.state})

    def test_output_symlinks_are_refused_without_touching_targets(self):
        for output in (self.settings, self.state):
            for dangling in (False, True):
                with self.subTest(output=output.name, dangling=dangling):
                    self.declare({"theme": "dark"})
                    target = self.root / "target.json"
                    if not dangling:
                        target.write_text('{"custom": 1}')
                    output.symlink_to(target)
                    before = {path.name: path.read_bytes() for path in self.root.iterdir()
                              if not path.is_symlink()}
                    with self.assertRaises((subject.MergeError, OSError)):
                        subject.merge_settings(self.settings, self.managed, self.state)
                    self.assertTrue(output.is_symlink())
                    self.assertEqual({path.name: path.read_bytes() for path in self.root.iterdir()
                                      if not path.is_symlink()}, before)
                    output.unlink()
                    if target.exists():
                        target.unlink()

    def test_nonregular_output_refuses_without_writes(self):
        self.declare({"theme": "dark"})
        self.settings.mkdir()
        with self.assertRaises(subject.MergeError):
            subject.merge_settings(self.settings, self.managed, self.state)
        self.assertFalse(self.state.exists())
        self.assertEqual(list(self.settings.iterdir()), [])

    def test_same_input_output_path_is_refused(self):
        self.declare({"theme": "dark"})
        before = self.managed.read_bytes()
        with self.assertRaises(subject.MergeError):
            subject.merge_settings(self.managed, self.managed, self.state)
        self.assertEqual(self.managed.read_bytes(), before)
        self.assertFalse(self.state.exists())

    def test_recovery_after_settings_or_final_state_commit_failure(self):
        for failed_commit in ("settings", "final-state"):
            with self.subTest(failed_commit=failed_commit):
                self.apply({})
                self.apply({"obsolete": {"leaf": 1}})
                value = self.settings_value()
                value["custom"] = {"keep": True}
                self.settings.write_text(json.dumps(value))
                self.declare({"intermediate": {"leaf": 2}})
                replace = subject._replace
                state_writes = 0

                def interrupt(directory, parent, name, data):
                    nonlocal state_writes
                    if name == self.state.name:
                        state_writes += 1
                    if ((failed_commit == "settings" and name == self.settings.name)
                            or (failed_commit == "final-state" and name == self.state.name
                                and state_writes == 2)):
                        raise OSError("simulated interrupted commit")
                    return replace(directory, parent, name, data)

                with patch.object(subject, "_replace", side_effect=interrupt):
                    with self.assertRaises(OSError):
                        subject.merge_settings(self.settings, self.managed, self.state)
                expected = {"custom": {"keep": True}}
                expected["obsolete" if failed_commit == "settings" else "intermediate"] = {
                    "leaf": 1 if failed_commit == "settings" else 2
                }
                self.assertEqual(self.settings_value(), expected)
                # A different declaration must still clean both possible ownerships.
                self.apply({"final": 3})
                self.assertEqual(self.settings_value(), {"custom": {"keep": True}, "final": 3})
                self.assertFalse(self.apply({"final": 3}))
                self.assertEqual(set(self.root.iterdir()),
                                 {self.settings, self.managed, self.state})

    def test_uncommitted_parent_ownership_does_not_delete_custom_children(self):
        self.settings.write_text('{"group": {"custom": 7}}')
        self.apply({"group": {"managed": 1}})
        self.declare({"group": "replacement"})
        replace = subject._replace

        def interrupt(directory, parent, name, data):
            if name == self.settings.name:
                raise OSError("settings commit failed")
            return replace(directory, parent, name, data)

        with patch.object(subject, "_replace", side_effect=interrupt):
            with self.assertRaises(OSError):
                subject.merge_settings(self.settings, self.managed, self.state)
        self.apply({})
        self.assertEqual(self.settings_value(), {"group": {"custom": 7}})

    def test_ambiguous_interrupted_commit_refuses_without_mutation(self):
        self.apply({"old": 1})
        self.declare({"new": 2})
        replace = subject._replace

        def interrupt(directory, parent, name, data):
            if name == self.settings.name:
                raise OSError("settings commit failed")
            return replace(directory, parent, name, data)

        with patch.object(subject, "_replace", side_effect=interrupt):
            with self.assertRaises(OSError):
                subject.merge_settings(self.settings, self.managed, self.state)
        self.settings.write_text('{"old": 1, "custom": true}')
        before = (self.settings.read_bytes(), self.state.read_bytes())
        with self.assertRaises(subject.MergeError):
            subject.merge_settings(self.settings, self.managed, self.state)
        self.assertEqual((self.settings.read_bytes(), self.state.read_bytes()), before)

    def test_cli_reports_invalid_json_without_mutation(self):
        self.declare({"theme": "dark"})
        self.settings.write_text("not JSON")
        errors = io.StringIO()
        with redirect_stderr(errors):
            status = subject.main(["--settings", str(self.settings),
                                   "--managed", str(self.managed), "--state", str(self.state)])
        self.assertEqual(status, 1)
        self.assertIn("invalid JSON", errors.getvalue())
        self.assertEqual(self.settings.read_text(), "not JSON")
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
