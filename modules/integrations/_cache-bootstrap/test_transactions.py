"""Filesystem transaction regressions; no host services are contacted."""
from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import errno
import io
import os
from pathlib import Path
import signal
import stat
import unittest
from unittest import mock

import daemon
import services
from test_bootstrap import IsolatedTests, LixTests, KEY, NEW_KEY, OFFICIAL, fragment


REAL_SECURE = daemon.check_secure
REAL_REPLACE = os.replace


def secure_as_root(path: Path) -> None:
    """Replace only ownership; retain actual file kind and permission checks."""
    metadata = list(path.lstat())
    metadata[4] = 0
    with mock.patch.object(Path, "lstat", return_value=os.stat_result(metadata)):
        REAL_SECURE(path)


class FilesystemGuards(IsolatedTests):
    def test_entrypoint_rejects_non_root_and_all_arguments(self) -> None:
        output = io.StringIO()
        with redirect_stderr(output):
            with mock.patch.object(daemon.os, "geteuid", return_value=1000):
                self.assertEqual(daemon.main([]), 1)
            with mock.patch.object(daemon.os, "geteuid", return_value=0):
                for args in (["nix"], ["/unreachable/nix"], ["--help"]):
                    self.assertEqual(daemon.main(args), 1)
        self.assertIn("Root is required", output.getvalue())
        self.assertIn("Expected no arguments", output.getvalue())

    def test_secure_rejects_symlink_and_writable_file(self) -> None:
        target = self.root / "target"
        target.write_text("admin")
        target.chmod(0o666)
        with self.assertRaisesRegex(RuntimeError, "writable"):
            secure_as_root(target)
        link = self.root / "link"
        link.symlink_to(target)
        with self.assertRaisesRegex(RuntimeError, "symlink"):
            secure_as_root(link)

    def test_secure_rejects_non_root_owner(self) -> None:
        path = self.root / "file"
        path.touch()
        metadata = list(path.lstat())
        metadata[4] = 12345
        with mock.patch.object(Path, "lstat", return_value=os.stat_result(metadata)):
            with self.assertRaisesRegex(RuntimeError, "root-owned"):
                REAL_SECURE(path)

    def test_malformed_fragment_refused_before_any_install(self) -> None:
        conf = self.root / "nix"
        conf.mkdir()
        main = conf / "nix.conf"
        main.write_text("require-sigs = true\n")
        for policy in (fragment() + "trusted-users = *\n", fragment(url="https://fixture.invalid/ # injected"),
                       fragment().replace("extra-substituters", "include"), "", fragment().replace("sha256:", "sha512:")):
            with self.subTest(policy=policy), mock.patch.object(daemon, "check_secure", side_effect=secure_as_root):
                with self.assertRaises(RuntimeError):
                    daemon.transaction(conf, policy, "/unreachable/nix", lambda: self.fail("restart"), lambda: self.fail("wait"))
                self.assertEqual(main.read_text(), "require-sigs = true\n")
                self.assertFalse((conf / "aw1cks-caches.conf").exists())
                self.assertFalse((conf / ".aw1cks-caches.lock").exists())

    def test_stale_lock_is_retained(self) -> None:
        lock = self.root / ".aw1cks-caches.lock"
        lock.mkdir()
        with mock.patch.object(daemon, "check_secure", side_effect=secure_as_root):
            with self.assertRaisesRegex(RuntimeError, "prior run was interrupted"):
                daemon.transaction(self.root, fragment(), "/unreachable/nix", lambda: None, lambda: None)
        self.assertTrue(lock.is_dir())

    def test_entrypoint_refuses_service_validation_failure_before_install(self) -> None:
        output = io.StringIO()
        service = mock.Mock()
        service.validate.side_effect = RuntimeError("unverified daemon identity")
        original_path = list(daemon.sys.path)
        self.addCleanup(daemon.sys.path.__setitem__, slice(None), original_path)
        with mock.patch.dict(os.environ, {"NIX_CONF_DIR": "/etc/nix"}, clear=True), \
                mock.patch.object(daemon.os, "geteuid", return_value=0), \
                mock.patch.object(Path, "exists", return_value=False), \
                mock.patch.object(daemon.os.path, "lexists", return_value=False), \
                mock.patch.object(daemon.pwd, "getpwuid", return_value=mock.Mock(pw_dir=str(self.root))), \
                mock.patch.object(services, "detect_service", return_value=service), \
                mock.patch.object(daemon, "transaction", side_effect=AssertionError("unverified installation")), \
                redirect_stderr(output):
            self.assertEqual(daemon.main([]), 1)
        self.assertIn("unverified daemon identity", output.getvalue())


class TransactionTests(LixTests):
    def setUp(self) -> None:
        super().setUp()
        self.conf = self.root / "etc-nix"
        self.conf.mkdir(mode=0o755)
        self.main = self.conf / "nix.conf"
        self.main.write_text("# Standalone install\nrequire-sigs = true\n"
                             "substituters = https://cache.nixos.org/\n"
                             f"trusted-public-keys = {OFFICIAL}\n")
        self.main.chmod(0o644)
        self.dest = self.conf / "aw1cks-caches.conf"
        self.restarts = 0
        self.fail_restart = False
        self.fail_wait = False
        for patcher in (
            mock.patch.dict(os.environ, self.env, clear=True),
            mock.patch.object(daemon, "check_secure", side_effect=secure_as_root),
            mock.patch.object(daemon.os, "chown"),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def restart(self) -> None:
        self.restarts += 1
        if self.fail_restart:
            self.fail_restart = False
            raise RuntimeError("fixture restart failure")

    def wait(self) -> None:
        if self.fail_wait:
            raise RuntimeError("fixture daemon unreachable")

    def sync(self, policy: str = None, ok: bool = True) -> str:
        output = io.StringIO()
        with redirect_stderr(output), redirect_stdout(output):
            if ok:
                daemon.transaction(self.conf, fragment() if policy is None else policy, self.nix, self.restart, self.wait)
            else:
                with self.assertRaises((OSError, RuntimeError)):
                    daemon.transaction(self.conf, fragment() if policy is None else policy, self.nix, self.restart, self.wait)
        self.assertFalse((self.conf / ".aw1cks-caches.lock").exists())
        return output.getvalue()

    def identity(self) -> tuple[int, int]:
        metadata = self.main.stat()
        return metadata.st_ino, metadata.st_mtime_ns

    def test_enrollment_repeat_and_private_backups(self) -> None:
        before = self.main.read_bytes()
        self.sync()
        self.assertTrue(self.main.read_bytes().startswith(before))
        self.assertEqual(self.dest.read_text(), fragment())
        self.assertEqual(stat.S_IMODE(self.dest.stat().st_mode), 0o644)
        self.assertEqual(self.main.read_text().count("include " + str(self.dest)), 1)
        identity = self.identity()
        installed = self.main.read_bytes()
        self.sync()
        self.assertEqual(self.identity(), identity)
        self.assertEqual(self.main.read_bytes(), installed)
        backups = list(self.conf.glob(".aw1cks-caches.*"))
        self.assertEqual(len(backups), 2)
        for directory in backups:
            self.assertEqual(stat.S_IMODE(directory.stat().st_mode), 0o700)
            for child in directory.iterdir():
                self.assertEqual(stat.S_IMODE(child.stat().st_mode), 0o600)
            self.assertFalse((directory / "check").exists())

    @unittest.skipUnless(hasattr(os, "setxattr") and hasattr(os, "getxattr"),
                         "Python does not expose extended attributes")
    def test_extended_attributes_survive_enrollment_backups_and_rollback(self) -> None:
        name = "user.aw1cks-cache-test"
        value = b"administrator metadata"
        try:
            os.setxattr(self.main, name, value)
        except OSError as error:
            if error.errno in (errno.ENOTSUP, errno.EOPNOTSUPP, errno.ENOSYS,
                               errno.EPERM, errno.EACCES):
                self.skipTest("Filesystem does not support writable user extended attributes")
            raise
        self.fail_restart = True
        self.sync(ok=False)
        self.assertEqual(os.getxattr(self.main, name), value)
        for directory in self.conf.glob(".aw1cks-caches.*"):
            self.assertEqual(os.getxattr(directory / "main.before", name), value)
        self.sync()
        self.assertEqual(os.getxattr(self.main, name), value)
        os.setxattr(self.dest, name, value)
        self.fail_restart = True
        self.sync(fragment(KEY + " " + NEW_KEY), ok=False)
        self.assertEqual(os.getxattr(self.dest, name), value)
        self.assertEqual(self.dest.read_text(), fragment())

    def test_existing_fragment_without_block_enrolls(self) -> None:
        self.dest.write_text(fragment())
        self.dest.chmod(0o644)
        self.sync()
        self.assertEqual(self.main.read_text().count("include " + str(self.dest)), 1)

    def test_malformed_blocks_and_external_owner(self) -> None:
        original = self.main.read_text()
        for addition in (daemon.BEGIN + "\n", daemon.END + "\n", f"!include {self.dest}\n",
                         f"{daemon.BEGIN}\n!include {self.dest}\n{daemon.END}\n",
                         f"{daemon.BEGIN}\ninclude {self.dest}\n{daemon.END}\nrequire-sigs = false\n",
                         "# Generated by nix-darwin\n"):
            with self.subTest(addition=addition):
                self.main.write_text(original + addition)
                self.sync(ok=False)
                self.assertEqual(self.main.read_text(), original + addition)
                self.assertFalse(self.dest.exists())

    def test_symlinks_and_permissions_preserved_on_rejection(self) -> None:
        original = self.main.read_bytes()
        real = self.root / "real-main"
        self.main.rename(real)
        self.main.symlink_to(real)
        self.sync(ok=False)
        self.assertTrue(self.main.is_symlink())
        self.main.unlink()
        real.rename(self.main)
        self.main.chmod(0o666)
        self.sync(ok=False)
        self.assertEqual(self.main.read_bytes(), original)
        self.main.chmod(0o644)
        target = self.root / "real-fragment"
        target.write_text(fragment())
        self.dest.symlink_to(target)
        self.sync(ok=False)
        self.assertTrue(self.dest.is_symlink())

    def test_unknown_fragment_is_not_overwritten(self) -> None:
        self.dest.write_text("# admin owned\n")
        self.sync(ok=False)
        self.assertEqual(self.dest.read_text(), "# admin owned\n")

    def test_real_parser_rejects_warning_missing_include_and_disabled_signatures(self) -> None:
        original = self.main.read_text()
        for addition in ("aw1cks-unknown-setting = true\n", "include missing.conf\n", "require-sigs = false\n"):
            with self.subTest(addition=addition):
                self.main.write_text(original + addition)
                self.sync(ok=False)
                self.assertEqual(self.main.read_text(), original + addition)
                self.assertFalse(self.dest.exists())

    def test_relative_admin_includes_keep_original_directory(self) -> None:
        nested = self.conf / "nested"
        nested.mkdir()
        (nested / "admin.conf").write_text("include child.conf\n")
        (nested / "child.conf").write_text("connect-timeout = 5\n")
        with self.main.open("a") as stream:
            stream.write("include nested/admin.conf\n")
        self.sync()
        self.assertIn("include nested/admin.conf\n", self.main.read_text())

    def home_config(self, text: str) -> None:
        home = Path(self.env["HOME"]) / ".config/nix/nix.conf"
        home.parent.mkdir(parents=True, exist_ok=True)
        home.write_text(text)
        os.environ.pop("XDG_CONFIG_HOME", None)

    def test_root_default_signature_conflict(self) -> None:
        self.home_config("require-sigs = false\n")
        before = self.main.read_bytes()
        self.sync(ok=False)
        self.assertEqual(self.main.read_bytes(), before)
        self.assertFalse(self.dest.exists())

    def test_root_default_retired_key_conflict(self) -> None:
        self.home_config(f"extra-trusted-public-keys = {KEY}\n")
        self.sync()
        self.sync(fragment(NEW_KEY), ok=False)
        self.assertEqual(self.dest.read_text(), fragment())

    def test_admin_duplicate_retired_key_conflict(self) -> None:
        with self.main.open("a") as stream:
            stream.write(f"extra-trusted-public-keys = {KEY}\n")
        self.sync()
        self.sync(fragment(NEW_KEY), ok=False)
        self.assertEqual(self.dest.read_text(), fragment())

    def test_revocation_and_failed_restart_never_restore_retired_trust(self) -> None:
        self.sync()
        self.fail_restart = True
        output = self.sync(fragment(NEW_KEY), ok=False)
        self.assertIn("refusing to restore retired trust", output)
        self.assertEqual(self.dest.read_text(), fragment(NEW_KEY))
        self.assertNotIn(KEY, self.dest.read_text())

    def test_cache_removal_is_also_irreversible(self) -> None:
        self.sync()
        self.fail_wait = True
        self.sync(fragment(url="https://replacement.invalid/"), ok=False)
        self.assertEqual(self.dest.read_text(), fragment(url="https://replacement.invalid/"))

    def test_initial_restart_and_wait_failure_roll_back(self) -> None:
        before = self.main.read_bytes()
        for failure in ("fail_restart", "fail_wait"):
            with self.subTest(failure=failure):
                setattr(self, failure, True)
                self.sync(ok=False)
                setattr(self, failure, False)
                self.assertEqual(self.main.read_bytes(), before)
                self.assertFalse(self.dest.exists())

    def test_additive_rollback_never_rewrites_main(self) -> None:
        self.sync()
        with self.main.open("ab") as stream:
            stream.write(b"\n# administrator trailing comment without newline")
        identity = self.identity()
        before = self.main.read_bytes()
        self.fail_restart = True
        self.sync(fragment(KEY + " " + NEW_KEY), ok=False)
        self.assertEqual(self.identity(), identity)
        self.assertEqual(self.main.read_bytes(), before)
        self.assertEqual(self.dest.read_text(), fragment())

    def rename_boundary(self, stage: str, after: bool, interrupt: bool = True):
        def replace(source, destination):
            if Path(source).name == stage + ".new":
                if after:
                    REAL_REPLACE(source, destination)
                if interrupt:
                    os.kill(os.getpid(), signal.SIGTERM)
                raise OSError("fixture rename failure")
            return REAL_REPLACE(source, destination)
        return replace

    def test_initial_interrupted_before_and_after_each_rename(self) -> None:
        before = self.main.read_bytes()
        for stage in ("fragment", "main"):
            for after in (False, True):
                with self.subTest(stage=stage, after=after):
                    with mock.patch.object(daemon.os, "replace", side_effect=self.rename_boundary(stage, after)):
                        self.sync(ok=False)
                    self.assertEqual(self.main.read_bytes(), before)
                    self.assertFalse(self.dest.exists())

    def test_successful_rotation_removes_retired_key(self) -> None:
        self.sync()
        identity = self.identity()
        self.sync(fragment(NEW_KEY))
        self.assertEqual(self.dest.read_text(), fragment(NEW_KEY))
        self.assertNotIn(KEY, self.dest.read_text())
        self.assertEqual(self.identity(), identity)

    def test_rotation_interrupted_before_and_after_fragment_rename(self) -> None:
        self.sync()
        identity = self.identity()
        for after in (False, True):
            with self.subTest(after=after):
                with mock.patch.object(daemon.os, "replace", side_effect=self.rename_boundary("fragment", after)):
                    self.sync(fragment(NEW_KEY), ok=False)
                self.assertEqual(self.dest.read_text(), fragment(NEW_KEY) if after else fragment())
                self.assertEqual(self.identity(), identity)

    def test_rotation_first_rename_failure_keeps_old_policy(self) -> None:
        self.sync()
        with mock.patch.object(daemon.os, "replace", side_effect=self.rename_boundary("fragment", False, False)):
            self.sync(fragment(NEW_KEY), ok=False)
        self.assertEqual(self.dest.read_text(), fragment())

    def test_removal_validation_failure_preserves_installed_policy(self) -> None:
        self.sync()
        with self.main.open("a") as stream:
            stream.write("require-sigs = false\n")
        before = self.main.read_bytes()
        identity = self.identity()
        for policy in (fragment(NEW_KEY), fragment(url="https://replacement.invalid/")):
            with self.subTest(policy=policy):
                self.sync(policy, ok=False)
                self.assertEqual(self.main.read_bytes(), before)
                self.assertEqual(self.identity(), identity)
                self.assertEqual(self.dest.read_text(), fragment())

    def test_enrollment_with_removal_interrupted_at_each_rename(self) -> None:
        before = self.main.read_bytes()
        for policy in (fragment(NEW_KEY), fragment(url="https://replacement.invalid/")):
            for stage in ("fragment", "main"):
                for after in (False, True):
                    with self.subTest(policy=policy, stage=stage, after=after):
                        self.main.write_bytes(before)
                        self.dest.write_text(fragment())
                        identity = self.identity()
                        with mock.patch.object(daemon.os, "replace",
                                               side_effect=self.rename_boundary(stage, after)):
                            self.sync(policy, ok=False)
                        published = stage == "main" or after
                        self.assertEqual(self.dest.read_text(), policy if published else fragment())
                        if stage == "main" and after:
                            self.assertEqual(self.main.read_text().count("include " + str(self.dest)), 1)
                        else:
                            self.assertEqual(self.main.read_bytes(), before)
                            self.assertEqual(self.identity(), identity)

    def test_rollback_failure_retains_private_backups(self) -> None:
        before = self.main.read_bytes()
        self.fail_restart = True
        def replace(source, destination):
            if Path(source).name.endswith(".rollback"):
                raise OSError("fixture rollback failure")
            return REAL_REPLACE(source, destination)
        with mock.patch.object(daemon.os, "replace", side_effect=replace):
            output = self.sync(ok=False)
        self.assertIn("rollback FAILED", output)
        backups = list(self.conf.glob(".aw1cks-caches.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "main.before").read_bytes(), before)
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o700)
        for child in backups[0].iterdir():
            self.assertEqual(stat.S_IMODE(child.stat().st_mode), 0o600)


if __name__ == "__main__":
    unittest.main()
