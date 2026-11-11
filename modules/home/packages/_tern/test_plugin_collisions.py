"""Read-only migration boundaries for native plugin directories and aliases."""

import os
from pathlib import Path
import runpy
import stat
import tempfile
import unittest
from unittest.mock import patch


GUARD = runpy.run_path(str(Path(__file__).with_name("check-plugin-collisions.py")))
check_collisions = GUARD["check_collisions"]
InspectionError = GUARD["InspectionError"]


class PluginCollisionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.root = self.base / "plugins"
        self.root.mkdir()
        self.data = self.base / "plugin-data" / "example"
        self.data.mkdir(parents=True)
        (self.data / "kv.json").write_text('{"keep":true}\n')

    def package(self, path, plugin_id="example"):
        path.mkdir(parents=True)
        (path / "plugin.toml").write_text(
            f'schema = 1\nid = "{plugin_id}"\nname = "Example"\n'
            'version = "1"\nhost = "host.luau"\n', encoding="utf-8"
        )
        (path / "host.luau").write_text('error("must never execute")\n', encoding="utf-8")
        return path

    def snapshot(self):
        result = {}
        for path in sorted(self.base.rglob("*")):
            metadata = path.lstat()
            content = None
            if path.is_symlink():
                content = os.readlink(path)
            elif stat.S_ISREG(metadata.st_mode):
                content = path.read_bytes()
            result[str(path.relative_to(self.base))] = (
                metadata.st_mode, metadata.st_mtime_ns, content
            )
        return result

    def check(self, *, rejected=False, selected=None):
        before = self.snapshot()
        try:
            if rejected:
                with self.assertRaises(InspectionError) as raised:
                    check_collisions(self.root, ["example"] if selected is None else selected)
                return str(raised.exception)
            check_collisions(self.root, ["example"] if selected is None else selected)
        finally:
            self.assertEqual(before, self.snapshot())

    def test_installed_directory_rejected_without_mutation(self):
        source = self.package(self.root / "example")
        (source / "plugin.toml").chmod(0o640)
        message = self.check(rejected=True)
        for expected in ("example", str(source), str(self.root / "example.path"),
                         "outside the plugin root", "data is retained"):
            self.assertIn(expected, message)

    def test_alias_manifest_identity_not_directory_name(self):
        self.package(self.root / "another-name")
        self.check(rejected=True)

    def test_symlinked_directory_duplicate(self):
        source = self.package(self.base / "outside")
        (self.root / "linked").symlink_to(source, target_is_directory=True)
        self.check(rejected=True)

    def test_numeric_prefix_matches_managed_registry_id_contract(self):
        self.package(self.root / "alias", "7-plugin")
        self.check(rejected=True, selected=["7-plugin"])

    def test_path_alias_duplicate_and_symlinked_pointer(self):
        source = self.package(self.base / "outside")
        pointer = self.base / "manual.path"
        pointer.write_text(f"  {source}\n")
        (self.root / "alias.path").symlink_to(pointer)
        self.check(rejected=True)
        (self.root / "alias.path").unlink()
        (self.root / "alias.path").write_text(f"{source}\n")
        self.check(rejected=True)

    def test_nonmatching_plugin_and_permissions_preserved(self):
        self.package(self.root / "other", "other")
        (self.root / "manual.path").write_text("/nonexistent/plugin\n")
        (self.root / "manual.path").chmod(0o640)
        self.check()

    def test_exact_managed_pointer_slot_allows_generation_update(self):
        source = self.package(self.base / "old-generation")
        (self.root / "example.path").write_text(f"{source}\n")
        self.check()
        (self.root / "example.path").unlink()
        (self.root / "example.path").symlink_to(self.base / "absent-old-generation")
        self.check()

    def test_no_root_and_no_selected_ids(self):
        self.root.rmdir()
        self.check()
        self.root.write_text("not a directory")
        self.check(selected=[])

    def test_disabled_ids_are_not_guarded(self):
        self.package(self.root / "example")
        self.check(selected=["other"])

    def test_hidden_and_unloadable_nonpackages_are_ignored(self):
        self.package(self.root / ".staging")
        (self.root / "notes").write_text("not a plugin")
        (self.root / "no-manifest").mkdir()
        malformed = self.root / "malformed"
        malformed.mkdir()
        (malformed / "plugin.toml").write_text('[broken\n')
        (self.root / "relative.path").write_text(".staging\n")
        (self.root / "empty.path").write_text(" \n")
        (self.root / "broken-link").symlink_to(self.base / "absent")
        self.check()

    def test_unsupported_schema_and_missing_entry_are_nonpackages(self):
        directory = self.root / "invalid"
        directory.mkdir()
        manifest = directory / "plugin.toml"
        for text in ('schema = 2\nid = "example"\nhost = "host.luau"\n',
                     'schema = 1\nid = "example"\n'):
            with self.subTest(text=text):
                manifest.write_text(text)
                self.check()

    def test_manifest_and_pointer_reads_are_bounded(self):
        package = self.package(self.root / "example")
        (package / "plugin.toml").write_bytes(b"#" * (GUARD["MAX_MANIFEST_BYTES"] + 1))
        self.check()
        (package / "plugin.toml").unlink()
        (self.root / "large.path").write_bytes(b"x" * (GUARD["MAX_POINTER_BYTES"] + 1))
        self.check(rejected=True)

    def test_special_files_are_not_read(self):
        os.mkfifo(self.root / "special.path")
        directory = self.root / "not-a-package"
        directory.mkdir()
        os.mkfifo(directory / "plugin.toml")
        (self.root / "manifest-directory" / "plugin.toml").mkdir(parents=True)
        self.check()

    def test_unreadable_candidate_fails_cleanly_without_mutation(self):
        source = self.package(self.root / "alias")
        real_open = os.open

        def inaccessible(path, flags, *args, **kwargs):
            if Path(path) == source / "plugin.toml":
                raise PermissionError("inspection denied")
            return real_open(path, flags, *args, **kwargs)

        with patch.object(os, "open", side_effect=inaccessible):
            message = self.check(rejected=True)
        self.assertIn(str(source), message)
        self.assertIn("example", message)
        self.assertIn("inspection denied", message)

    def test_unreadable_plugin_root_fails_cleanly(self):
        real_iterdir = Path.iterdir

        def inaccessible(path):
            if path == self.root:
                raise PermissionError("inspection denied")
            return real_iterdir(path)

        before = self.snapshot()
        with patch.object(Path, "iterdir", inaccessible):
            with self.assertRaisesRegex(InspectionError, "cannot inspect plugin root"):
                check_collisions(self.root, ["example"])
        self.assertEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main()
