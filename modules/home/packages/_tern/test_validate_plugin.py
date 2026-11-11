"""Build-time plugin manifest acceptance and source containment boundaries."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


VALIDATOR = Path(__file__).with_name("validate-plugin.py")


class PluginManifestTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "plugin"
        self.source.mkdir()
        (self.source / "host.luau").write_text("return {}\n", encoding="utf-8")
        (self.root / "outside.luau").write_text("return {}\n", encoding="utf-8")

    def manifest(self, **overrides):
        fields = {
            "schema": 1,
            "id": "fixture-plugin",
            "name": "Fixture plugin",
            "version": "1.0.0",
            "host": "host.luau",
        }
        fields.update(overrides)
        text = "\n".join(
            f"{key} = {json.dumps(value)}"
            for key, value in fields.items()
            if value is not None
        )
        (self.source / "plugin.toml").write_text(text + "\n", encoding="utf-8")

    def validate(self, *, accepted):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--id", "fixture-plugin",
             "--source", str(self.source)],
            capture_output=True,
            text=True,
            check=False,
        )
        if accepted:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertTrue(result.stderr.strip(), "Rejection needs a diagnostic")
        return result

    def test_minimal_host_manifest(self):
        self.manifest()
        self.validate(accepted=True)

    def test_empty_version_is_upstream_compatible(self):
        self.manifest(version="")
        self.validate(accepted=True)

    def test_lua_entry_is_supported(self):
        (self.source / "host.lua").write_text("return {}\n", encoding="utf-8")
        self.manifest(host="host.lua")
        self.validate(accepted=True)

    def test_window_only_manifest_with_nested_entry(self):
        (self.source / "nested").mkdir()
        (self.source / "nested" / "window.luau").write_text(
            "return {}\n", encoding="utf-8"
        )
        self.manifest(host=None, window="nested/window.luau")
        self.validate(accepted=True)

    def test_manifest_id_must_match_registry_id(self):
        self.manifest(id="different-plugin")
        self.validate(accepted=False)

    def test_schema_requires_integer_version_one(self):
        for schema in (None, 0, 2, "1", True):
            with self.subTest(schema=schema):
                self.manifest(schema=schema)
                self.validate(accepted=False)

    def test_missing_or_malformed_manifest(self):
        self.validate(accepted=False)
        (self.source / "plugin.toml").write_text("[broken\n", encoding="utf-8")
        self.validate(accepted=False)

    def test_manifest_needs_an_entry(self):
        self.manifest(host=None)
        self.validate(accepted=False)

    def test_entries_must_be_existing_files_inside_source(self):
        (self.source / "directory.luau").mkdir()
        (self.source / "escape.luau").symlink_to(self.root / "outside.luau")
        for entry in (
            "../outside.luau",
            str(self.root / "outside.luau"),
            "escape.luau",
            "missing.luau",
            "directory.luau",
        ):
            for field in ("host", "window"):
                with self.subTest(entry=entry, field=field):
                    self.manifest(**{field: entry})
                    self.validate(accepted=False)

    def test_entry_requires_lua_extension(self):
        (self.source / "host.txt").write_text("return {}\n", encoding="utf-8")
        self.manifest(host="host.txt")
        self.validate(accepted=False)

    def test_styles_are_relative_contained_files(self):
        (self.source / "style.css").write_text(":root {}\n", encoding="utf-8")
        self.manifest(styles=["style.css"])
        self.validate(accepted=True)
        (self.source / "escape.css").symlink_to(self.root / "outside.luau")
        for styles in (
            "style.css",
            ["../outside.luau"],
            [str(self.root / "outside.luau")],
            ["escape.css"],
            ["missing.css"],
        ):
            with self.subTest(styles=styles):
                self.manifest(styles=styles)
                self.validate(accepted=False)


if __name__ == "__main__":
    unittest.main()
