"""Isolated security regressions for the managed daemon's mutable state."""

import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).with_name("prepare-state.py")


class PrepareStateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="kata-state-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.state = self.root / "state"
        self.token = self.state / "auth-token"

    def command(self):
        return [sys.executable, str(HELPER), "--state", str(self.state)]

    def prepare(self, *, success=True):
        result = subprocess.run(
            self.command(), capture_output=True, text=True, timeout=30
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def make_state(self):
        self.state.mkdir(mode=0o700)

    def write_token(self, content=b"existing-private-token\n", mode=0o600):
        self.make_state()
        self.token.write_bytes(content)
        self.token.chmod(mode)

    def snapshot(self, path):
        metadata = path.lstat()
        return (
            metadata.st_dev,
            metadata.st_ino,
            metadata.st_uid,
            metadata.st_gid,
            metadata.st_mode,
            metadata.st_size,
            metadata.st_mtime_ns,
        )

    def assert_rejected_unchanged(self):
        before = self.snapshot(self.token)
        content = self.token.read_bytes() if stat.S_ISREG(before[4]) else None
        self.prepare(success=False)
        self.assertEqual(self.snapshot(self.token), before)
        if content is not None:
            self.assertEqual(self.token.read_bytes(), content)

    def test_initialization_is_private_and_stable(self):
        self.prepare()
        directory = self.state.lstat()
        token = self.token.lstat()
        self.assertTrue(stat.S_ISDIR(directory.st_mode))
        self.assertEqual(stat.S_IMODE(directory.st_mode), 0o700)
        self.assertEqual(directory.st_uid, os.getuid())
        self.assertTrue(stat.S_ISREG(token.st_mode))
        self.assertEqual(stat.S_IMODE(token.st_mode), 0o600)
        self.assertEqual(token.st_uid, os.getuid())
        content = self.token.read_text(encoding="utf-8")
        self.assertGreaterEqual(len(content), 32)
        before = self.snapshot(self.token)
        self.prepare()
        self.assertEqual(self.snapshot(self.token), before)
        self.assertEqual(self.token.read_text(encoding="utf-8"), content)

    def test_existing_token_and_database_are_preserved(self):
        self.write_token()
        database = self.state / "kata.db"
        database.write_bytes(b"existing database contents")
        before = self.snapshot(self.token)
        database_before = self.snapshot(database)
        self.prepare()
        self.assertEqual(self.snapshot(self.token), before)
        self.assertEqual(self.token.read_bytes(), b"existing-private-token\n")
        self.assertEqual(self.snapshot(database), database_before)
        self.assertEqual(database.read_bytes(), b"existing database contents")

    def test_symlink_token_is_rejected_without_touching_target(self):
        self.make_state()
        target = self.root / "target"
        target.write_bytes(b"do not modify")
        target.chmod(0o600)
        self.token.symlink_to(target)
        before = self.snapshot(target)
        self.assert_rejected_unchanged()
        self.assertEqual(self.snapshot(target), before)
        self.assertEqual(target.read_bytes(), b"do not modify")

    def test_directory_token_is_rejected(self):
        self.make_state()
        self.token.mkdir(mode=0o700)
        self.assert_rejected_unchanged()

    def test_fifo_token_is_rejected_without_blocking(self):
        self.make_state()
        os.mkfifo(self.token, 0o600)
        self.assert_rejected_unchanged()

    def test_empty_token_is_rejected(self):
        self.write_token(b"")
        self.assert_rejected_unchanged()

    def test_oversize_token_is_rejected(self):
        self.write_token(b"x" * (65536 + 1))
        self.assert_rejected_unchanged()

    def test_maximum_size_token_is_preserved(self):
        self.write_token(b"x" * 65536)
        before = self.snapshot(self.token)
        self.prepare()
        self.assertEqual(self.snapshot(self.token), before)
        self.assertEqual(self.token.read_bytes(), b"x" * 65536)

    def test_invalid_utf8_token_is_rejected(self):
        self.write_token(b"\xff\xfe")
        self.assert_rejected_unchanged()

    def test_group_or_other_permissions_are_rejected(self):
        self.write_token()
        for mode in (0o640, 0o620, 0o610, 0o604, 0o602, 0o601):
            with self.subTest(mode=oct(mode)):
                self.token.chmod(mode)
                self.assert_rejected_unchanged()

    @unittest.skipUnless(os.geteuid() == 0, "Changing file ownership requires root")
    def test_foreign_owned_token_is_rejected(self):
        self.write_token()
        os.chown(self.token, 1, -1)
        try:
            self.assert_rejected_unchanged()
        finally:
            os.chown(self.token, os.getuid(), -1)

    def test_symlink_state_is_rejected_without_populating_target(self):
        target = self.root / "real-state"
        target.mkdir(mode=0o700)
        self.state.symlink_to(target, target_is_directory=True)
        before = self.snapshot(self.state)
        self.prepare(success=False)
        self.assertEqual(self.snapshot(self.state), before)
        self.assertEqual(list(target.iterdir()), [])

    def test_regular_file_state_is_rejected(self):
        self.state.write_bytes(b"not a directory")
        before = self.snapshot(self.state)
        self.prepare(success=False)
        self.assertEqual(self.snapshot(self.state), before)
        self.assertEqual(self.state.read_bytes(), b"not a directory")

    def test_concurrent_initialization_publishes_one_private_token(self):
        processes = []
        try:
            for _ in range(8):
                processes.append(
                    subprocess.Popen(
                        self.command(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        text=True,
                    )
                )
            for process in processes:
                _, stderr = process.communicate(timeout=30)
                self.assertEqual(process.returncode, 0, stderr)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.kill()
                    process.communicate()
        content = self.token.read_bytes()
        self.assertGreaterEqual(len(content), 32)
        content.decode("utf-8")
        self.assertEqual(stat.S_IMODE(self.token.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.state.stat().st_mode), 0o700)
        self.assertEqual(set(self.state.iterdir()), {self.token})
        before = self.snapshot(self.token)
        self.prepare()
        self.assertEqual(self.snapshot(self.token), before)
        self.assertEqual(self.token.read_bytes(), content)


if __name__ == "__main__":
    unittest.main()
