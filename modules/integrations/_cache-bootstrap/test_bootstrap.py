"""Bootstrap boundaries and real Lix source selection, without host activation."""
from __future__ import annotations

import errno
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
import venv

import bootstrap

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OFFICIAL = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
KEY = "fixture:" + "A" * 43 + "="
NEW_KEY = "fixture:" + "B" * 43 + "="


def fragment(key: str = KEY, url: str = "https://fixture.invalid/") -> str:
    return (
        "# Managed by aw1cks cache bootstrap v1\n"
        f"# Inventory sha256: {'a' * 64}\n"
        f"extra-substituters = {url}\n"
        f"extra-trusted-public-keys = {key}\n"
    )


def executable(path: Path, body: str) -> None:
    path.write_text(f"#!{sys.executable}\n" + body)
    path.chmod(0o755)


def isolated_env(root: Path) -> dict[str, str]:
    env = dict(os.environ)
    for name in tuple(env):
        if name.startswith("NIX_") or name == "IN_NIX_SHELL":
            env.pop(name)
    for name, child in (
        ("HOME", "home"), ("XDG_CONFIG_HOME", "xdg"),
        ("XDG_CONFIG_DIRS", "xdg-system"), ("XDG_CACHE_HOME", "cache"),
        ("XDG_STATE_HOME", "state"), ("NIX_CONF_DIR", "empty-nix"),
    ):
        directory = root / child
        directory.mkdir(exist_ok=True)
        env[name] = str(directory)
    env["NIX_CONFIG"] = ""
    env["NIX_USER_CONF_FILES"] = "/dev/null"
    return env


class IsolatedTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="cache-tests-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.env = isolated_env(self.root)


class LixTests(IsolatedTests):
    @classmethod
    def setUpClass(cls) -> None:
        cls.nix = shutil.which("nix")
        if cls.nix is None:
            raise unittest.SkipTest("Lix is not installed")
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                [cls.nix, "--version"], env=isolated_env(Path(temporary).resolve()),
                text=True, capture_output=True,
            )
        if result.returncode or "lix" not in result.stdout.lower():
            raise unittest.SkipTest("The installed nix is not Lix")


class ApprovalTests(IsolatedTests):
    def test_controlling_terminal_accepts_yes_and_defaults_to_no(self) -> None:
        for answer, approved in ((b"yes\n", True), (b"\n", False)):
            with self.subTest(answer=answer):
                marker = self.root / "approved"
                marker.unlink(missing_ok=True)
                script = (
                    f"import sys; sys.path.insert(0, {str(HERE)!r}); "
                    "from bootstrap import approve; from pathlib import Path\n"
                    "try:\n    approve(False)\n"
                    "except RuntimeError:\n    raise SystemExit(42)\n"
                    f"Path({str(marker)!r}).write_text('approved')\n"
                )
                try:
                    pid, terminal = pty.fork()
                except OSError as error:
                    if error.errno in (errno.ENOENT, errno.EPERM, errno.ENODEV, errno.EACCES):
                        self.skipTest("The sandbox does not provide a controlling PTY")
                    raise
                if pid == 0:
                    os.execve(sys.executable, [sys.executable, "-I", "-S", "-c", script], self.env)
                status = None
                transcript = bytearray()
                try:
                    os.write(terminal, answer)
                    deadline = time.monotonic() + 10
                    while True:
                        remaining = deadline - time.monotonic()
                        self.assertGreater(remaining, 0, "Confirmation hung")
                        self.assertTrue(select.select([terminal], [], [], remaining)[0], "Confirmation hung")
                        try:
                            chunk = os.read(terminal, 4096)
                        except OSError as error:
                            if error.errno == errno.EIO:
                                break
                            raise
                        if not chunk:
                            break
                        transcript.extend(chunk)
                    _, status = os.waitpid(pid, 0)
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0 if approved else 42,
                                     transcript.decode(errors="replace"))
                    self.assertEqual(marker.exists(), approved)
                finally:
                    os.close(terminal)
                    if status is None:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        os.waitpid(pid, 0)


class InterpreterIsolationTests(IsolatedTests):
    def test_privileged_python_does_not_execute_virtualenv_startup_hooks(self) -> None:
        directory = self.root / "venv"
        venv.EnvBuilder(with_pip=False, symlinks=True).create(directory)
        interpreter = str(directory / "bin/python3")
        site = subprocess.run(
            [interpreter, "-I", "-c", "import sysconfig; print(sysconfig.get_path('purelib'))"],
            env=self.env, check=True, text=True, capture_output=True,
        ).stdout.strip()
        hook = self.root / "startup-hook"
        (Path(site) / "bootstrap-review.pth").write_text(
            f"import pathlib; pathlib.Path({str(hook)!r}).touch()\n")
        # Establish that this interpreter really executes the fixture with -I.
        subprocess.run([interpreter, "-I", "-c", "pass"], env=self.env, check=True)
        self.assertTrue(hook.exists())
        hook.unlink()
        executed = self.root / "executed"
        script = self.root / "approved-helper.py"
        script.write_text(f"from pathlib import Path\nPath({str(executed)!r}).touch()\n")
        # Do not invoke sudo: exercise the real child interpreter under the
        # sanitized environment as the test user, never a host provisioner.
        with mock.patch.object(bootstrap.os, "geteuid", return_value=0), \
                mock.patch.object(bootstrap.sys, "executable", interpreter):
            bootstrap.privileged_python(script, policy="")
        self.assertTrue(executed.exists())
        self.assertFalse(hook.exists())

    def test_user_writable_interpreter_is_rejected_before_execution(self) -> None:
        interpreter = self.root / "python"
        marker = self.root / "executed"
        executable(interpreter, f"from pathlib import Path\nPath({str(marker)!r}).touch()\n")
        interpreter.chmod(0o777)
        with mock.patch.object(bootstrap.sys, "executable", str(interpreter)):
            with self.assertRaises(RuntimeError):
                bootstrap.privileged_python(self.root / "helper.py", policy="")
        self.assertFalse(marker.exists())


class TargetTests(IsolatedTests):
    def test_refuses_nonlocal_missing_or_injected_targets(self) -> None:
        for value in ("github:some/repo#host", str(self.root) + "#host", ".", ".#", '.#host";echo bad'):
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                bootstrap.local_target(value)

    def test_resolves_symlink_checkout(self) -> None:
        checkout = self.root / "checkout % with spaces"
        checkout.mkdir()
        (checkout / "flake.nix").write_text("{}")
        alias = self.root / "alias"
        alias.symlink_to(checkout, target_is_directory=True)
        self.assertEqual(bootstrap.local_target(str(alias) + "#host"),
                         bootstrap.local_target(str(checkout) + "#host"))


class ProbeTests(unittest.TestCase):
    def test_rejects_derivations_and_output_selection_before_store_access(self) -> None:
        path = "/nix/store/" + "0" * 32 + "-fixture"
        for suffix in (".drv", ".drv!out", "!out"):
            with self.subTest(suffix=suffix), mock.patch.object(bootstrap.os, "geteuid", return_value=1000), \
                    mock.patch.object(bootstrap.subprocess, "run") as run:
                with self.assertRaises(RuntimeError):
                    bootstrap.probe("/installed/bin/nix", path + suffix)
                run.assert_not_called()

    def test_root_cannot_claim_an_ordinary_user_probe(self) -> None:
        with mock.patch.object(bootstrap.os, "geteuid", return_value=0), \
                mock.patch.object(bootstrap.subprocess, "run") as run:
            with self.assertRaises(RuntimeError):
                bootstrap.probe("/installed/bin/nix", "/nix/store/" + "0" * 32 + "-fixture")
            run.assert_not_called()

    def test_existing_store_path_is_not_realised_or_deleted(self) -> None:
        path = "/nix/store/" + "0" * 32 + "-fixture"
        with mock.patch.object(bootstrap.os, "geteuid", return_value=1000), \
                mock.patch.object(bootstrap.os.path, "lexists", return_value=True), \
                mock.patch.object(bootstrap.subprocess, "run") as run:
            with self.assertRaises(RuntimeError):
                bootstrap.probe("/installed/bin/nix", path)
            run.assert_not_called()


class RendererTests(LixTests):
    def evaluate(self, mode: str = "extra") -> subprocess.CompletedProcess[str]:
        # Isolate the host configuration while exercising the actual source CLI.
        wrapper = self.root / "bin"
        wrapper.mkdir(exist_ok=True)
        nix = wrapper / "nix"
        executable(nix, "import os, sys\n"
                   f'os.environ["NIX_CONF_DIR"] = {self.env["NIX_CONF_DIR"]!r}\n'
                   f'os.execv({self.nix!r}, [{self.nix!r}] + sys.argv[1:])\n')
        env = dict(self.env, PATH=str(wrapper) + os.pathsep + self.env["PATH"])
        env.pop("NIX_CONF_DIR")
        return subprocess.run(
            [sys.executable, str(HERE / "bootstrap.py"), "render", mode],
            env=env, text=True, capture_output=True,
        )

    def show(self, setting: str, config: str) -> str:
        result = subprocess.run(
            [self.nix, "--extra-experimental-features", "nix-command",
             "--offline", "--store", "dummy://", "config", "show", setting],
            env=dict(self.env, NIX_CONFIG=config), text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("warning:", result.stderr.lower())
        return result.stdout.strip()

    def test_modes_are_accepted_by_actual_parser(self) -> None:
        inherited_url = "https://inherited.invalid/"
        (Path(self.env["NIX_CONF_DIR"]) / "nix.conf").write_text(
            f"substituters = https://cache.nixos.org/ {inherited_url}\n"
            f"trusted-public-keys = {OFFICIAL} {KEY}\n"
        )
        for mode in ("extra", "replace", "official"):
            with self.subTest(mode=mode):
                result = self.evaluate(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                urls = self.show("substituters", result.stdout).split()
                keys = self.show("trusted-public-keys", result.stdout).split()
                self.assertIn("https://cache.nixos.org/", urls)
                self.assertIn(OFFICIAL, keys)
                if mode == "official":
                    self.assertEqual(urls, ["https://cache.nixos.org/"])
                    self.assertEqual(keys, [OFFICIAL])
                if mode == "extra":
                    self.assertIn(inherited_url, urls)
                    self.assertIn(KEY, keys)
                else:
                    self.assertNotIn(inherited_url, urls)
                    self.assertNotIn(KEY, keys)

    def test_recovery_overrides_inherited_lists(self) -> None:
        policy = self.evaluate("official")
        self.assertEqual(policy.returncode, 0, policy.stderr)
        (Path(self.env["NIX_CONF_DIR"]) / "nix.conf").write_text("substituters = https://dead.invalid/\n")
        user = self.root / "user.conf"
        user.write_text("extra-substituters = https://also-dead.invalid/\n")
        self.env["NIX_USER_CONF_FILES"] = str(user)
        self.assertEqual(self.show("substituters", policy.stdout), "https://cache.nixos.org/")
        self.assertIn("dead.invalid", self.show("substituters", "extra-substituters ="))

    def test_renderer_rejects_newline_in_inventory(self) -> None:
        result = subprocess.run(
            [self.nix, "--extra-experimental-features", "nix-command", "--store", "dummy://",
             "eval", "--offline", "--raw", "--option", "allow-import-from-derivation", "false",
             "--file", str(ROOT / "modules/shared/_render-cache-conf.nix"), "--apply",
             'f: f { caches = { substituters = [ "https://a\\ntrusted-users = *" ]; trustedPublicKeys = []; }; }'],
            env=self.env, text=True, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_real_lix_evaluates_local_checkout_with_reserved_characters(self) -> None:
        # Exercise Lix resolution rather than checking a constructed URL string.
        checkout = self.root / "flake with spaces % ? # café"
        checkout.mkdir()
        (checkout / "flake.nix").write_text('{ outputs = { self }: { marker = "reviewed-local-checkout"; }; }\n')
        checkout, target = bootstrap.local_target(str(checkout) + "#marker")
        result = subprocess.run(
            [self.nix, "--extra-experimental-features", "nix-command flakes", "--offline",
             "--store", "local?root=" + str(self.root / "store"), "eval", "--raw",
             "--no-write-lock-file", target], env=self.env, cwd=checkout, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "reviewed-local-checkout")

    def test_git_source_boundary_for_checkout_subdirectory_and_worktree(self) -> None:
        env = dict(self.env, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null")

        def git(*args: str, cwd: Path) -> None:
            subprocess.run(["git", "-c", "user.name=Bootstrap Fixture",
                            "-c", "user.email=bootstrap@example.invalid", *args],
                           cwd=cwd, env=env, check=True, capture_output=True)

        for kind in ("checkout", "subdirectory", "worktree"):
            with self.subTest(kind=kind):
                repo = self.root / f"{kind} with spaces % ? # café"
                repo.mkdir()
                git("init", "--quiet", cwd=repo)
                flake = repo / "nested" if kind == "subdirectory" else repo
                flake.mkdir(exist_ok=True)
                (repo / ".gitignore").write_text("ignored-secret\n")
                (flake / "flake.nix").write_text(
                    '{ outputs = { self }: { review = { '
                    'tracked = builtins.readFile ./tracked.txt; '
                    'ignored = builtins.pathExists ./ignored-secret; '
                    'gitDirectory = builtins.pathExists ./.git; }; }; }\n')
                (flake / "tracked.txt").write_text("tracked fixture")
                git("add", ".", cwd=repo)
                if kind == "worktree":
                    git("-c", "core.hooksPath=/dev/null", "commit", "--quiet",
                        "--no-gpg-sign", "--message", "fixture", cwd=repo)
                    flake = self.root / "linked worktree % ? # café"
                    git("worktree", "add", "--quiet", "--detach", str(flake), cwd=repo)
                (flake / "ignored-secret").write_text("NONSECRET_REGRESSION_FIXTURE")
                checkout, target = bootstrap.local_target(str(flake) + "#review")
                result = subprocess.run(
                    [self.nix, "--extra-experimental-features", "nix-command flakes",
                     "--offline", "--store", "local?root=" + str(self.root / "store"),
                     "eval", "--json", "--no-write-lock-file", target],
                    cwd=checkout, env=env, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), {
                    "tracked": "tracked fixture", "ignored": False, "gitDirectory": False,
                })


if __name__ == "__main__":
    unittest.main(verbosity=2)
