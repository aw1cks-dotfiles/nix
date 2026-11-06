"""Decision regressions using stock service shapes; never contact a host manager."""
from __future__ import annotations

import os
from pathlib import Path
import plistlib
import stat
import tempfile
import unittest
from unittest.mock import patch

import services

NIX = "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-lix-2.95.4/bin/nix"
DAEMON = NIX + "-daemon"
WRAPPER = f"/bin/wait4path /nix/store && exec {DAEMON}"
VERSION = "nix (Lix, like Nix) 2.95.4\n"
OTHER_NIX = "/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-lix-2.93.3/bin/nix"
OTHER_DAEMON = OTHER_NIX + "-daemon"


def exec_start(executable: str = DAEMON, argv: str = "nix-daemon --daemon") -> str:
    # Stock systemd ExecStart property, including the @ argv[0] override in
    # lix-project/lix misc/systemd/nix-daemon.service.in, release 2.93.3.
    return (f"{{ path={executable} ; argv[]={argv} ; ignore_errors=no ; "
            "start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }")


def launch_print(plist: Path, argv: list[str], env: dict[str, str]) -> str:
    # Shape observed on macOS 26 with the installer-provided Lix 2.95.4 plist.
    arguments = "\n".join("\t\t" + value for value in argv)
    environment = "\n".join(f"\t\t{key} => {value}" for key, value in env.items())
    return f"""system/{services.LABEL} = {{
\tactive count = 1
\tpath = {plist}
\ttype = LaunchDaemon
\tstate = running
\tprogram = {argv[0]}
\targuments = {{
{arguments}
\t}}
\tdefault environment = {{
\t\tPATH => /usr/bin:/bin:/usr/sbin:/sbin
\t}}
\tenvironment = {{
\t\tOSLogRateLimit => 64
{environment}
\t\tXPC_SERVICE_NAME => {services.LABEL}
\t}}
\tdomain = system
\tpid = 123
\tresource coalition = {{
\t\tID = 579
\t\ttype = resource
\t}}
\tproperties = keepalive | inferred program
}}
"""


class DefinitionMetadataTests(unittest.TestCase):
    def metadata(self, mode: int, uid: int = 0) -> os.stat_result:
        return os.stat_result((mode, 0, 0, 1, uid, 30000, 0, 0, 0, 0))

    def test_canonical_root_owned_sticky_group_writable_store_accepted(self) -> None:
        services.check_definition_component(
            Path("/nix/store"), self.metadata(stat.S_IFDIR | 0o1775),
        )

    def test_store_exception_is_not_a_general_sticky_directory_exception(self) -> None:
        for path, mode, uid in (
            ("/tmp", stat.S_IFDIR | 0o1775, 0),
            ("/tmp/store", stat.S_IFDIR | 0o1775, 0),
            ("/nix/store", stat.S_IFDIR | 0o0775, 0),
            ("/nix/store", stat.S_IFDIR | 0o1777, 0),
            ("/nix/store", stat.S_IFDIR | 0o1775, 1),
            ("/nix/store/installation", stat.S_IFDIR | 0o1775, 0),
            ("/nix/store/unit.service", stat.S_IFREG | 0o1775, 0),
        ):
            with self.subTest(path=path, mode=oct(mode), uid=uid):
                with self.assertRaises(RuntimeError):
                    services.check_definition_component(Path(path), self.metadata(mode, uid))


class ExecutableTests(unittest.TestCase):
    """Map a real private fixture onto canonical store names without root."""

    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.installation = self.root / "installation"
        self.bindir = self.installation / "bin"
        self.bindir.mkdir(parents=True)
        self.nix = self.bindir / "nix"
        self.nix.write_bytes(b"fixture executable")
        self.nix.chmod(0o755)
        self.daemon = self.bindir / "nix-daemon"
        self.daemon.symlink_to("nix")
        self.store = Path("/nix/store/security-fixture")
        self.untrusted = None
        original_resolve = Path.resolve
        original_lstat = Path.lstat
        original_stat = Path.stat
        original_access = os.access

        def mapped(path: Path) -> Path:
            if path == self.store or self.store in path.parents:
                return self.installation / path.relative_to(self.store)
            return path

        def resolve(path: Path, strict: bool = False) -> Path:
            resolved = original_resolve(mapped(path), strict=strict)
            if resolved == self.installation or self.installation in resolved.parents:
                return self.store / resolved.relative_to(self.installation)
            return resolved

        def metadata(path: Path, follow: bool = False, **kwargs) -> os.stat_result:
            if path in (Path("/"), Path("/nix"), Path("/nix/store")):
                mode = stat.S_IFDIR | (0o1775 if path == Path("/nix/store") else 0o755)
                return os.stat_result((mode, 0, 0, 1, 0, 0, 0, 0, 0, 0))
            result = list((original_stat if follow else original_lstat)(mapped(path), **kwargs))
            result[4] = 1 if mapped(path) == self.untrusted else 0
            return os.stat_result(result)

        for patcher in (
            patch.object(Path, "resolve", resolve),
            patch.object(Path, "lstat", lambda path: metadata(path)),
            patch.object(Path, "stat", lambda path, **kwargs: metadata(path, True, **kwargs)),
            patch.object(os, "access", lambda path, mode: original_access(mapped(Path(path)), mode)),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_secure_daemon_alias_and_sibling_frontend_accepted(self) -> None:
        services.secure_executable(str(self.store / "bin/nix-daemon"))
        services.secure_executable(str(self.store / "bin/nix"))

    def test_untrusted_daemon_alias_binary_or_directory_rejected(self) -> None:
        for path in (self.daemon, self.nix, self.bindir, self.installation):
            with self.subTest(path=path):
                self.untrusted = path
                with self.assertRaises(RuntimeError):
                    services.secure_executable(str(self.store / "bin/nix-daemon"))

    def test_writable_binary_or_directory_rejected(self) -> None:
        for path in (self.nix, self.bindir, self.installation):
            with self.subTest(path=path):
                mode = path.stat().st_mode & 0o777
                path.chmod(mode | 0o020)
                try:
                    with self.assertRaises(RuntimeError):
                        services.secure_executable(str(self.store / "bin/nix-daemon"))
                finally:
                    path.chmod(mode)

    def test_alias_escaping_installation_rejected(self) -> None:
        outside = self.root / "outside"
        outside.write_bytes(b"unrelated executable")
        outside.chmod(0o755)
        self.daemon.unlink()
        self.daemon.symlink_to(outside)
        with self.assertRaises(RuntimeError):
            services.secure_executable(str(self.store / "bin/nix-daemon"))

    def test_non_executable_binary_rejected(self) -> None:
        self.nix.chmod(0o644)
        with self.assertRaises(RuntimeError):
            services.secure_executable(str(self.store / "bin/nix"))


class SystemdTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.fragment = self.root / "nix-daemon.service"
        self.fragment.write_text("[Service]\nExecStart=@" + DAEMON + " nix-daemon --daemon\n")
        self.props = {key: "" for key in services.PROPERTIES}
        self.props.update(LoadState="loaded", NeedDaemonReload="no", DynamicUser="no", ProtectHome="no", PrivateUsers="no",
                          FragmentPath=str(self.fragment), ExecStart=exec_start())
        self.manager = "PATH=/usr/bin:/bin\nLANG=en_US.UTF-8\n"
        self.extra = ""
        self.restarts = 0
        self.versions: dict[str, str] = {}
        self.addCleanup(patch.stopall)
        self.untrusted_node = None
        original_lstat = Path.lstat

        def root_owned_lstat(path: Path):
            # Simulate a root-owned installation without requiring root tests.
            # Retain real file types, links, and permissions inside the fixture;
            # only unrelated host temp-directory ancestors get secure modes.
            metadata = list(original_lstat(path))
            metadata[4] = 1 if path == self.untrusted_node else 0
            if path != self.root and self.root not in path.parents:
                metadata[0] &= ~0o022
            return os.stat_result(metadata)

        patch.object(Path, "lstat", root_owned_lstat).start()
        patch.object(services, "secure_file", side_effect=lambda path: path.read_bytes()).start()
        patch.object(services, "secure_executable").start()
        patch.object(services, "run", side_effect=self.manager_call).start()
        self.service = services.SystemdService()

    def manager_call(self, *args: str) -> str:
        if len(args) == 2 and args[1] == "--version" and args[0].startswith("/nix/store/"):
            return self.versions.get(args[0], VERSION)
        if args[:2] == ("systemctl", "show"):
            return "".join(f"{key}={value}\n" for key, value in self.props.items()) + self.extra
        if args == ("systemctl", "show-environment"):
            return self.manager
        if args == ("systemctl", "restart", services.UNIT):
            self.restarts += 1
            return ""
        raise AssertionError(args)

    def test_standard_daemon_commands(self) -> None:
        for executable, argv in ((DAEMON, "nix-daemon --daemon"),
                                 (DAEMON, DAEMON), (DAEMON, DAEMON + " --daemon"),
                                 (NIX, NIX + " daemon")):
            with self.subTest(argv=argv):
                self.props["ExecStart"] = exec_start(executable, argv)
                service = services.SystemdService()
                self.assertEqual(service.validate(), NIX)
                self.assertEqual(service.version, VERSION.strip())
                service.restart()
        self.assertEqual(self.restarts, 4)

    def test_all_nonstandard_flags_are_rejected(self) -> None:
        for flags in ("--option substituters https://evil.invalid", "--substituters https://evil.invalid",
                      "--trusted-public-keys evil", "--extra-substituters https://evil.invalid",
                      "--extra-trusted-public-keys retired:" + "A" * 43 + "=",
                      "--no-substitute", "--no-require-sigs", "--store /tmp/store", "--help"):
            for prefix in (DAEMON, DAEMON + " --daemon"):
                with self.subTest(flags=flags, prefix=prefix):
                    self.props["ExecStart"] = exec_start(DAEMON, prefix + " " + flags)
                    with self.assertRaises(RuntimeError):
                        services.SystemdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_config_environment_in_manager_and_service(self) -> None:
        for name in ("HOME", "XDG_CONFIG_HOME", "XDG_CONFIG_DIRS", "NIX_CONFIG",
                     "NIX_CONF_DIR", "NIX_USER_CONF_FILES", "NIX_REMOTE", "NIX_FUTURE_OVERRIDE", "LD_PRELOAD"):
            for location in ("manager", "service"):
                with self.subTest(name=name, location=location):
                    self.manager = f"{name}=/tmp/alternate\n" if location == "manager" else ""
                    self.props["Environment"] = f"{name}=/tmp/alternate" if location == "service" else ""
                    with self.assertRaises(RuntimeError):
                        services.SystemdService().validate()

    def test_config_environment_cannot_be_hidden_by_pass_or_unset(self) -> None:
        for key in services.EMPTY_PROPERTIES:
            with self.subTest(key=key):
                self.props[key] = "override"
                with self.assertRaises(RuntimeError):
                    services.SystemdService().validate()
                self.props[key] = ""

    def test_stale_disk_definition(self) -> None:
        self.props["NeedDaemonReload"] = "yes"
        with self.assertRaises(RuntimeError):
            self.service.validate()
        self.assertEqual(self.restarts, 0)

    def test_missing_unknown_duplicate_and_malformed_properties(self) -> None:
        original = self.props.copy()
        for mutation in ("missing", "unknown", "duplicate", "exec"):
            with self.subTest(mutation=mutation):
                self.props = original.copy()
                self.extra = ""
                if mutation == "missing":
                    del self.props["EnvironmentFiles"]
                elif mutation == "unknown":
                    self.extra = "FuturePolicy=override\n"
                elif mutation == "duplicate":
                    self.extra = "Environment=NIX_CONFIG=evil\n"
                else:
                    self.props["ExecStart"] += " ; second command"
                with self.assertRaises(RuntimeError):
                    services.SystemdService().validate()

    def test_independent_daemon_installation_selects_matching_parser(self) -> None:
        self.props["ExecStart"] = exec_start(OTHER_DAEMON, OTHER_DAEMON)
        other_version = "nix (Lix, like Nix) 2.93.3\n"
        self.versions = {OTHER_DAEMON: other_version, OTHER_NIX: other_version}
        self.assertEqual(self.service.validate(), OTHER_NIX)
        self.assertEqual(self.service.version, other_version.strip())
        self.service.restart()
        self.assertEqual(self.restarts, 1)

    def test_upstream_unknown_or_mismatched_daemon_installation_rejected(self) -> None:
        for executable in (DAEMON, NIX):
            for version in ("nix (Nix) 2.24.0\n", "Lix development build\n", "",
                            "nix (Lix, like Nix) 2.93.3\n"):
                with self.subTest(executable=executable, version=version):
                    self.versions = {executable: version}
                    with self.assertRaises(RuntimeError):
                        services.SystemdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_noncanonical_daemon_paths_rejected(self) -> None:
        for executable in ("/run/current-system/sw/bin/nix-daemon",
                           "/nix/store/../evil/bin/nix-daemon",
                           "/tmp/lix/bin/nix-daemon",
                           "/nix/store/installation/bin/custom-daemon"):
            with self.subTest(executable=executable):
                self.props["ExecStart"] = exec_start(executable, executable)
                with self.assertRaises(RuntimeError):
                    services.SystemdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_command_installation_change_blocks_restart(self) -> None:
        self.service.validate()
        self.props["ExecStart"] = exec_start(OTHER_DAEMON, OTHER_DAEMON)
        with self.assertRaises(RuntimeError):
            self.service.restart()
        self.assertEqual(self.restarts, 0)

    def test_executable_identity_change_blocks_restart(self) -> None:
        with patch.object(services, "secure_executable", return_value=("original",)):
            self.service.validate()
        with patch.object(services, "secure_executable", return_value=("replacement",)):
            with self.assertRaises(RuntimeError):
                self.service.restart()
        self.assertEqual(self.restarts, 0)

    def test_changed_snapshot_blocks_restart_even_if_still_allowed(self) -> None:
        for change in ("disk", "loaded", "manager"):
            with self.subTest(change=change):
                self.setUp_snapshot_change(change)
        self.assertEqual(self.restarts, 0)

    def setUp_snapshot_change(self, change: str) -> None:
        service = services.SystemdService()
        service.validate()
        if change == "disk":
            self.fragment.write_text(self.fragment.read_text() + "# changed\n")
        elif change == "loaded":
            self.props["Environment"] = "LANG=C"
        else:
            self.manager += "TZ=UTC\n"
        with self.assertRaises(RuntimeError):
            service.restart()

    def test_restart_requires_initial_validation(self) -> None:
        with self.assertRaises(RuntimeError):
            self.service.restart()
        self.assertEqual(self.restarts, 0)

    def linked_definition(self) -> Path:
        installation = self.root / "installation"
        unit = installation / "lib/systemd/system/nix-daemon.service"
        unit.parent.mkdir(parents=True)
        unit.write_bytes(self.fragment.read_bytes())
        (self.root / "generation").symlink_to("installation", target_is_directory=True)
        (self.root / "default").symlink_to("generation", target_is_directory=True)
        linked = self.root / "linked.service"
        linked.symlink_to("default/lib/systemd/system/nix-daemon.service")
        self.props["FragmentPath"] = str(linked)
        return linked

    def test_stock_linked_unit_and_profile_chain_accepted(self) -> None:
        self.linked_definition()
        self.service.validate()
        self.service.restart()
        self.assertEqual(self.restarts, 1)

    def test_untrusted_symlink_or_target_rejected(self) -> None:
        linked = self.linked_definition()
        for node in (linked, self.root / "default", self.root / "installation",
                     self.root / "installation/lib/systemd/system/nix-daemon.service"):
            with self.subTest(node=node):
                self.untrusted_node = node
                with self.assertRaises(RuntimeError):
                    services.SystemdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_writable_definition_directory_or_target_rejected(self) -> None:
        self.linked_definition()
        for node in (self.root / "installation",
                     self.root / "installation/lib/systemd/system/nix-daemon.service"):
            with self.subTest(node=node):
                mode = node.stat().st_mode & 0o777
                node.chmod(mode | 0o020)
                try:
                    with self.assertRaises(RuntimeError):
                        services.SystemdService().validate()
                finally:
                    node.chmod(mode)

    def test_profile_retarget_with_identical_bytes_blocks_restart(self) -> None:
        self.linked_definition()
        other = self.root / "other-installation/lib/systemd/system/nix-daemon.service"
        other.parent.mkdir(parents=True)
        other.write_bytes(self.fragment.read_bytes())
        self.service.validate()
        profile = self.root / "default"
        profile.unlink()
        profile.symlink_to("other-installation", target_is_directory=True)
        with self.assertRaises(RuntimeError):
            self.service.restart()
        self.assertEqual(self.restarts, 0)

    def test_symlink_loop_and_dangling_link_fail_closed(self) -> None:
        linked = self.root / "linked.service"
        linked.symlink_to("linked.service")
        self.props["FragmentPath"] = str(linked)
        with self.assertRaises(RuntimeError):
            self.service.validate()
        linked.unlink()
        linked.symlink_to("absent.service")
        with self.assertRaises(OSError):
            self.service.validate()


class LaunchdTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.plist = Path(self.tmp.name) / "org.nixos.nix-daemon.plist"
        self.definition = {
            "Label": services.LABEL,
            "ProgramArguments": ["/bin/sh", "-c", WRAPPER],
            "EnvironmentVariables": {"NIX_SSL_CERT_FILE": "/etc/ssl/certs/ca-certificates.crt",
                                     "OBJC_DISABLE_INITIALIZE_FORK_SAFETY": "YES"},
            "KeepAlive": True, "LowPriorityIO": False, "ProcessType": "Standard",
            "SoftResourceLimits": {"NumberOfFiles": 1048576},
        }
        self.write_plist()
        self.loaded = self.loaded_definition()
        self.domain = "system = {\n\ttype = system\n\tservices = {\n\t\t123 0 org.nixos.nix-daemon\n\t}\n}\n"
        self.restarts = 0
        self.versions: dict[str, str] = {}
        self.addCleanup(patch.stopall)
        patch.object(services, "PLIST", self.plist).start()
        patch.object(services, "secure_file", side_effect=lambda path: path.read_bytes()).start()
        patch.object(services, "secure_executable").start()
        patch.object(services, "run", side_effect=self.manager_call).start()
        self.service = services.LaunchdService()

    def write_plist(self) -> None:
        self.plist.write_bytes(plistlib.dumps(self.definition))

    def loaded_definition(self) -> str:
        return launch_print(self.plist, self.definition["ProgramArguments"], self.definition["EnvironmentVariables"])

    def manager_call(self, *args: str) -> str:
        if len(args) == 2 and args[1] == "--version" and args[0].startswith("/nix/store/"):
            return self.versions.get(args[0], VERSION)
        if args == ("launchctl", "print", "system/" + services.LABEL):
            return self.loaded
        if args == ("launchctl", "print", "system"):
            return self.domain
        if args == ("launchctl", "kickstart", "-k", "system/" + services.LABEL):
            self.restarts += 1
            return ""
        raise AssertionError(args)

    def test_standard_installer_wrapper_and_direct_commands(self) -> None:
        for argv in (["/bin/sh", "-c", WRAPPER], [DAEMON], [DAEMON, "--daemon"], [NIX, "daemon"]):
            with self.subTest(argv=argv):
                self.definition["ProgramArguments"] = argv
                self.write_plist()
                self.loaded = self.loaded_definition()
                service = services.LaunchdService()
                self.assertEqual(service.validate(), NIX)
                self.assertEqual(service.version, VERSION.strip())
                service.restart()
        self.assertEqual(self.restarts, 4)

    def test_wrapper_discovers_independent_daemon_installation(self) -> None:
        self.definition["ProgramArguments"] = ["/bin/sh", "-c", WRAPPER.replace(DAEMON, OTHER_DAEMON)]
        self.write_plist()
        self.loaded = self.loaded_definition()
        self.assertEqual(self.service.validate(), OTHER_NIX)

    def test_non_lix_daemon_and_parser_rejected(self) -> None:
        for executable in (DAEMON, NIX):
            with self.subTest(executable=executable):
                self.versions = {executable: "nix (Nix) 2.24.0\n"}
                with self.assertRaises(RuntimeError):
                    services.LaunchdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_loaded_and_disk_command_change_blocks_restart(self) -> None:
        self.service.validate()
        self.definition["ProgramArguments"] = [OTHER_DAEMON]
        self.write_plist()
        self.loaded = self.loaded_definition()
        with self.assertRaises(RuntimeError):
            self.service.restart()
        self.assertEqual(self.restarts, 0)

    def test_arbitrary_shell_and_all_extra_flags_rejected(self) -> None:
        commands = (["/bin/sh", "-c", WRAPPER + " --no-require-sigs"],
                    ["/bin/sh", "-c", "exec " + DAEMON],
                    ["/bin/sh", "-c", WRAPPER + "; true"],
                    [DAEMON, "--extra-substituters", "https://evil.invalid"],
                    [DAEMON, "--extra-trusted-public-keys", "retired:" + "A" * 43 + "="],
                    [DAEMON, "--no-require-sigs"],
                    [DAEMON, "--no-substitute"], [DAEMON, "--option", "require-sigs", "false"])
        for argv in commands:
            with self.subTest(argv=argv):
                self.definition["ProgramArguments"] = argv
                self.write_plist()
                self.loaded = self.loaded_definition()
                with self.assertRaises(RuntimeError):
                    services.LaunchdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_service_and_domain_config_environment_rejected(self) -> None:
        original = self.loaded
        for name in ("HOME", "XDG_CONFIG_HOME", "XDG_CONFIG_DIRS", "NIX_CONFIG",
                     "NIX_CONF_DIR", "NIX_USER_CONF_FILES", "NIX_FUTURE_OVERRIDE", "DYLD_INSERT_LIBRARIES"):
            for location in ("plist", "loaded", "default", "inherited", "domain"):
                with self.subTest(name=name, location=location):
                    self.definition["EnvironmentVariables"].pop(name, None)
                    self.loaded = original
                    self.domain = "system = {\n\ttype = system\n}\n"
                    block = f"\t{name} => /tmp/alternate\n"
                    if location == "plist":
                        self.definition["EnvironmentVariables"][name] = "/tmp/alternate"
                    elif location in ("loaded", "default"):
                        key = "environment" if location == "loaded" else "default environment"
                        self.loaded = self.loaded.replace(f"\t{key} = {{\n", f"\t{key} = {{\n" + block)
                    elif location == "inherited":
                        self.loaded = self.loaded.replace("\tdomain = system", "\tinherited environment = {\n" + block + "\t}\n\tdomain = system")
                    else:
                        self.domain = "system = {\n\ttype = system\n\tenvironment = {\n" + block + "\t}\n}\n"
                    self.write_plist()
                    with self.assertRaises(RuntimeError):
                        services.LaunchdService().validate()
                    self.definition["EnvironmentVariables"].pop(name, None)

    def test_loaded_command_and_environment_must_match_disk(self) -> None:
        for change in ("command", "environment"):
            with self.subTest(change=change):
                self.loaded = self.loaded_definition()
                if change == "command":
                    self.loaded = self.loaded.replace(WRAPPER, WRAPPER.replace("lix-2.95.4", "lix-other"))
                else:
                    self.loaded = self.loaded.replace("NIX_SSL_CERT_FILE => /etc/ssl/certs/ca-certificates.crt", "NIX_SSL_CERT_FILE => /tmp/other")
                with self.assertRaises(RuntimeError):
                    services.LaunchdService().validate()

    def test_unknown_ambiguous_and_missing_structure_rejected(self) -> None:
        original = self.loaded
        for output in ("", original.replace("\tprogram = /bin/sh\n", ""),
                       original.replace("\tprogram = /bin/sh\n", "\tprogram = /bin/sh\n\tprogram = /bin/sh\n"),
                       original.replace("\tdomain = system", "\tworking directory = /tmp\n\tdomain = system"),
                       original.replace("\targuments = {", "\tunknown arguments = {"),
                       original.replace("\tdefault environment = {", "\tdefault environment = unknown"),
                       original.replace("OSLogRateLimit => 64", "OSLogRateLimit => 64\n\t\tOSLogRateLimit => 64"),
                       original[:-3]):
            with self.subTest(output=output):
                self.loaded = output
                with self.assertRaises(RuntimeError):
                    services.LaunchdService().validate()
        self.assertEqual(self.restarts, 0)

    def test_unknown_plist_execution_settings_rejected(self) -> None:
        self.definition["WorkingDirectory"] = "/tmp"
        self.write_plist()
        with self.assertRaises(RuntimeError):
            self.service.validate()

    def test_changed_valid_snapshot_blocks_restart(self) -> None:
        for change in ("disk", "loaded", "domain"):
            with self.subTest(change=change):
                service = services.LaunchdService()
                service.validate()
                if change == "disk":
                    self.definition["KeepAlive"] = False
                    self.write_plist()
                elif change == "loaded":
                    self.loaded = self.loaded.replace("PATH => /usr/bin:/bin:/usr/sbin:/sbin", "PATH => /usr/bin:/bin")
                else:
                    self.domain = "system = {\n\ttype = system\n\tenvironment = {\n\t\tLANG => C\n\t}\n}\n"
                with self.assertRaises(RuntimeError):
                    service.restart()
        self.assertEqual(self.restarts, 0)

    def test_domain_unknown_or_ambiguous_structure_rejected(self) -> None:
        for output in ("", "system = {\n", "system = {\n}\n",
                       "system = {\n\ttype = system\n\tenvironment = unknown\n}\n",
                       "system = {\n\ttype = system\n\tenvironment = {\n\t}\n\tenvironment = {\n\t}\n}\n"):
            with self.subTest(output=output):
                self.domain = output
                with self.assertRaises(RuntimeError):
                    self.service.validate()


if __name__ == "__main__":
    unittest.main()
