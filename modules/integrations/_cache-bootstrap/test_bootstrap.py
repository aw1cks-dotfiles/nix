"""Portable regression tests; service/CLI mocks are not daemon integration proof."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

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


class TransactionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="cache-tests-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.conf = self.root / "etc-nix"
        self.conf.mkdir(mode=0o755)
        self.main = self.conf / "nix.conf"
        self.main.write_text(
            "# Standalone install\nrequire-sigs = true\n"
            "substituters = https://cache.nixos.org/\n"
            f"trusted-public-keys = {OFFICIAL}\n"
        )
        self.main.chmod(0o644)
        self.dest = self.conf / "aw1cks-caches.conf"
        # Small parser double for filesystem/error-path tests. Real Lix renderer
        # tests below and the optional VM test cover actual parsing/substitution.
        parser = self.root / "parse.py"
        parser.write_text('''import sys
from pathlib import Path
settings = {}
def read(path):
    for raw in Path(path).read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line: continue
        if line.startswith(("include ", "!include ")):
            kind, target = line.split(None, 1)
            other = Path(target)
            if not other.is_absolute(): other = Path(path).parent / other
            if kind == "!include" and not other.exists(): continue
            read(other)
        else:
            key, value = map(str.strip, line.split("=", 1))
            if key.startswith("extra-"):
                key = key[6:]
                settings[key] = (settings.get(key, "") + " " + value).strip()
            else: settings[key] = value
read(sys.argv[1])
for key, value in settings.items(): print(key + " = " + value)
''')
        self.harness = self.root / "harness.sh"
        self.harness.write_text(f'''#!/bin/sh
set -eu
. "{HERE / 'daemon-lib.sh'}"
# Tests run without root, and never touch a host daemon. Keep real mode checks.
cache_stat() {{
  case "$(uname -s)" in
    Darwin) value=$(stat -f '%Lp' "$1") ;;
    *) value=$(stat -c '%a' "$1") ;;
  esac
  printf '0:%s\\n' "$value"
}}
chown() {{ :; }}
cache_parse() {{
  [ ! -e "{self.root}/bad-parse" ] || return 1
  "{sys.executable}" "{parser}" "$1/nix.conf" > "$2" 2> "$3"
  if [ -e "{self.root}/parser-warning" ]; then echo 'warning: unknown setting' > "$3"; fi
}}
cache_restart() {{
  echo restart >> "{self.root}/restarts"
  if [ -e "{self.root}/fail-restart" ]; then rm "{self.root}/fail-restart"; return 1; fi
}}
cache_wait() {{ [ ! -e "{self.root}/fail-ping" ]; }}
mv() {{
  case "$*" in
    *main.new*)
      if [ -e "{self.root}/fail-main-write" ]; then rm "{self.root}/fail-main-write"; return 1; fi ;;
  esac
  command mv "$@"
}}
cache_transaction "$1"
''')

    def run_sync(self, text: str | None = None, ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            ["sh", str(self.harness), str(self.conf)], input=text or fragment(),
            text=True, capture_output=True,
        )
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.conf / ".aw1cks-caches.lock").exists())
        return result

    def test_initial_and_repeat_install(self) -> None:
        original = self.main.read_text()
        self.run_sync()
        first = self.main.read_text()
        self.assertTrue(first.startswith(original))
        self.assertEqual(self.dest.read_text(), fragment())
        self.assertEqual(self.dest.stat().st_mode & 0o777, 0o644)
        self.run_sync()
        self.assertEqual(self.main.read_text(), first)
        self.assertEqual(first.count("include " + str(self.dest)), 1)

    def test_rejects_configuration_injection(self) -> None:
        before = self.main.read_text()
        self.run_sync(fragment() + "trusted-users = *\n", ok=False)
        self.assertEqual(self.main.read_text(), before)
        self.assertFalse(self.dest.exists())

    def test_rejects_injected_token(self) -> None:
        self.run_sync(fragment(url="https://example.invalid/ # surprise"), ok=False)

    def test_rejects_unknown_existing_fragment(self) -> None:
        self.dest.write_text("# admin config\nextra-substituters = https://custom.invalid\n")
        self.run_sync(ok=False)
        self.assertIn("admin config", self.dest.read_text())

    def test_rejects_symlink_main(self) -> None:
        original = self.root / "real-config"
        self.main.rename(original)
        self.main.symlink_to(original)
        self.run_sync(ok=False)
        self.assertTrue(self.main.is_symlink())

    def test_rejects_symlink_fragment(self) -> None:
        original = self.root / "real-fragment"
        original.write_text(fragment())
        self.dest.symlink_to(original)
        self.run_sync(ok=False)
        self.assertTrue(self.dest.is_symlink())

    def test_rejects_writable_config(self) -> None:
        self.main.chmod(0o666)
        self.run_sync(ok=False)

    def test_rejects_managed_config(self) -> None:
        self.main.write_text("# Generated by nix-darwin\n")
        self.run_sync(ok=False)

    def test_rejects_unmarked_include(self) -> None:
        with self.main.open("a") as stream:
            stream.write(f"!include {self.dest}\n")
        self.run_sync(ok=False)

    def test_rejects_partial_block(self) -> None:
        with self.main.open("a") as stream:
            stream.write("# BEGIN aw1cks cache provisioning\n")
        self.run_sync(ok=False)

    def test_rejects_later_admin_override(self) -> None:
        self.run_sync()
        with self.main.open("a") as stream:
            stream.write("substituters = https://admin.invalid/\n")
        self.run_sync(ok=False)

    def test_relative_include_survives_validation(self) -> None:
        (self.conf / "admin.conf").write_text("connect-timeout = 5\n")
        with self.main.open("a") as stream:
            stream.write("include admin.conf\n")
        self.run_sync()
        self.assertIn("include admin.conf", self.main.read_text())

    def test_parser_failure_does_not_modify_files(self) -> None:
        before = self.main.read_text()
        (self.root / "bad-parse").touch()
        self.run_sync(ok=False)
        self.assertEqual(self.main.read_text(), before)
        self.assertFalse(self.dest.exists())

    def test_parser_warning_is_failure(self) -> None:
        (self.root / "parser-warning").touch()
        self.run_sync(ok=False)
        self.assertFalse(self.dest.exists())

    def test_require_sigs_false_is_rejected(self) -> None:
        self.main.write_text("require-sigs = false\n")
        self.run_sync(ok=False)
        self.assertFalse(self.dest.exists())

    def test_restart_failure_rolls_back_initial_install(self) -> None:
        before = self.main.read_text()
        (self.root / "fail-restart").touch()
        result = self.run_sync(ok=False)
        self.assertEqual(self.main.read_text(), before)
        self.assertFalse(self.dest.exists())
        self.assertIn("backups", result.stderr)

    def test_partial_commit_rolls_back(self) -> None:
        before = self.main.read_text()
        (self.root / "fail-main-write").touch()
        self.run_sync(ok=False)
        self.assertEqual(self.main.read_text(), before)
        self.assertFalse(self.dest.exists())

    def test_rotation_replaces_old_key(self) -> None:
        self.run_sync()
        self.run_sync(fragment(NEW_KEY))
        self.assertIn(NEW_KEY, self.dest.read_text())
        self.assertNotIn(KEY, self.dest.read_text())

    def test_rotation_restart_failure_does_not_restore_retired_key(self) -> None:
        self.run_sync()
        (self.root / "fail-restart").touch()
        result = self.run_sync(fragment(NEW_KEY), ok=False)
        self.assertIn(NEW_KEY, self.dest.read_text())
        self.assertNotIn(KEY, self.dest.read_text())
        self.assertIn("refusing to restore retired trust", result.stderr)

    def test_rotation_detects_duplicate_key_in_admin_config(self) -> None:
        with self.main.open("a") as stream:
            stream.write(f"extra-trusted-public-keys = {KEY}\n")
        self.run_sync()
        result = self.run_sync(fragment(NEW_KEY), ok=False)
        self.assertIn("outside the owned fragment", result.stderr)
        self.assertIn(KEY, self.dest.read_text())


class EntryPointTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="bootstrap-tests-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.jsonl"
        self.flake = self.root / "flake with spaces"
        self.flake.mkdir()
        (self.flake / "flake.nix").write_text("{}")
        log = f"with open({str(self.log)!r}, 'a') as out: out.write(json.dumps({{'args': sys.argv, 'config': os.environ.get('NIX_CONFIG'), 'remote': os.environ.get('NIX_REMOTE'), 'user_conf': os.environ.get('NIX_USER_CONF_FILES')}}) + '\\n')\n"
        executable(self.bin / "nix", "import sys, os, json\n" + log + f'''
if '--version' in sys.argv: print('nix (Lix, like Nix) 2.test')
elif 'eval' in sys.argv:
    mode = sys.argv[-1]
    if mode == 'official':
        print('substituters = https://cache.nixos.org/\\ntrusted-public-keys = {OFFICIAL}')
    else: print({fragment()!r}, end='')
''')
        executable(self.bin / "sudo", "import sys, os, json\n" + log + "\nsys.exit(0)\n")
        executable(self.bin / "id", "import sys\nprint('1000')\n")
        executable(self.bin / "uname", "import os\nprint(os.environ.get('TEST_OS', 'Darwin'))\n")
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.env.pop("NIX_CONF_DIR", None)
        self.env["NIX_CONFIG"] = "post-build-hook = /do-not-forward\nextra-substituters = https://dead.invalid/"
        self.script = HERE / "bootstrap.sh"

    def run_cli(self, *args: str, ok: bool = True) -> list[dict]:
        self.log.unlink(missing_ok=True)
        result = subprocess.run(["sh", str(self.script), *args], env=self.env, text=True, capture_output=True)
        self.result = result
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_help_needs_no_nix(self) -> None:
        (self.bin / "nix").unlink()
        self.run_cli("--help")

    def test_renderer_does_not_run_flake(self) -> None:
        calls = self.run_cli("render")
        evaluation = next(c for c in calls if "eval" in c["args"])
        self.assertIn("--offline", evaluation["args"])
        self.assertIn("allow-import-from-derivation", evaluation["args"])
        self.assertEqual(evaluation["config"], "")
        self.assertNotIn("run", evaluation["args"])

    def test_darwin_bootstrap_sets_policy_at_sudo_boundary(self) -> None:
        calls = self.run_cli("--yes", "bootstrap", "darwin", str(self.flake) + "#mac")
        elevated = next(c for c in calls if c["args"][0].endswith("sudo"))
        args = elevated["args"]
        config = next(a for a in args if a.startswith("NIX_CONFIG="))
        self.assertIn("accept-flake-config = false", config)
        self.assertIn(KEY, config)
        self.assertNotIn("post-build-hook", config)
        self.assertNotIn("dead.invalid", config)
        self.assertIn("NIX_REMOTE=daemon", args)
        self.assertIn("NIX_USER_CONF_FILES=/dev/null", args)
        self.assertIn(str(self.flake) + "#darwin", args)
        self.assertNotIn("-E", args)

    def test_recovery_replaces_lists(self) -> None:
        calls = self.run_cli("--yes", "--recovery", "bootstrap", "darwin", str(self.flake) + "#mac")
        args = next(c for c in calls if c["args"][0].endswith("sudo"))["args"]
        config = next(a for a in args if a.startswith("NIX_CONFIG="))
        self.assertIn("\nsubstituters = https://cache.nixos.org/", config)
        self.assertIn(OFFICIAL, config)
        self.assertNotIn("extra-substituters", config)

    def test_hm_activation_is_not_elevated(self) -> None:
        calls = self.run_cli("--yes", "bootstrap", "standalone-hm", str(self.flake) + "#user@host")
        elevated = [c for c in calls if c["args"][0].endswith("sudo")]
        self.assertEqual(len(elevated), 1)
        self.assertTrue(any(a.endswith("daemon.sh") for a in elevated[0]["args"]))
        activation = next(c for c in calls if "run" in c["args"])
        self.assertIn(str(self.flake) + "#home-manager", activation["args"])
        self.assertEqual(activation["remote"], "daemon")

    def test_owner_is_explicit(self) -> None:
        self.run_cli("--yes", "bootstrap", "auto", str(self.flake) + "#mac", ok=False)

    def test_remote_flake_is_rejected(self) -> None:
        self.run_cli("--yes", "bootstrap", "darwin", "github:some/repo#mac", ok=False)

    def test_injected_target_is_rejected(self) -> None:
        self.run_cli("--yes", "bootstrap", "darwin", str(self.flake) + '#mac";echo bad', ok=False)

    def test_existing_probe_path_is_not_deleted(self) -> None:
        # /nix/store may not exist in the test container, but this path is an
        # argument-shape rejection and cannot trigger a build or deletion.
        self.run_cli("probe", str(self.flake), ok=False)
        self.assertTrue(self.flake.exists())


@unittest.skipUnless(shutil.which("nix"), "Lix is not installed in this test environment")
class RendererTests(unittest.TestCase):
    def evaluate(self, mode: str = "extra", extra: list[str] | None = None) -> subprocess.CompletedProcess[str]:
        env = dict(os.environ, NIX_CONFIG="", NIX_USER_CONF_FILES="/dev/null")
        return subprocess.run([
            "nix", "--extra-experimental-features", "nix-command", "--store", "dummy://",
            "eval", "--offline", "--option", "allow-import-from-derivation", "false",
            "--raw", "--file", str(ROOT / "modules/shared/_render-cache-conf.nix"),
            "--argstr", "mode", mode, *(extra or []),
        ], env=env, text=True, capture_output=True)

    def test_modes(self) -> None:
        for mode in ("extra", "replace", "official"):
            with self.subTest(mode=mode):
                result = self.evaluate(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("# Managed by aw1cks", result.stdout)
                self.assertIn("extra-substituters =" if mode == "extra" else "\nsubstituters =", result.stdout)
                self.assertEqual(OFFICIAL in result.stdout, mode != "extra")
                self.assertEqual("cache.lantian.pub" in result.stdout, mode != "official")

    def test_recovery_overrides_inherited_lists(self) -> None:
        policy = self.evaluate("official")
        self.assertEqual(policy.returncode, 0, policy.stderr)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "nix.conf").write_text("substituters = https://dead.invalid/\n")
            user = root / "user.conf"
            user.write_text("extra-substituters = https://also-dead.invalid/\n")
            env = dict(os.environ, NIX_CONF_DIR=directory, NIX_USER_CONF_FILES=str(user))
            def show(config: str) -> str:
                result = subprocess.run(
                    ["nix", "--extra-experimental-features", "nix-command", "config", "show", "substituters"],
                    env=dict(env, NIX_CONFIG=config), text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout.strip()
            self.assertEqual(show(policy.stdout), "https://cache.nixos.org/")
            self.assertIn("dead.invalid", show("extra-substituters ="))

    def test_bad_mode(self) -> None:
        self.assertNotEqual(self.evaluate("bogus").returncode, 0)

    def test_rejects_newline(self) -> None:
        injected = '{ substituters = [ "https://a\\ntrusted-users = *" ]; trustedPublicKeys = []; }'
        self.assertNotEqual(self.evaluate(extra=["--arg", "caches", injected]).returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
