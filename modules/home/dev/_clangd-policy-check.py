"""Exercise the rendered Home Manager policy through pinned clangd's LSP."""

import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import tempfile
import threading


ROOT = Path(os.environ["TMPDIR"]).resolve() / "clangd-policy"
ROOT.mkdir()
HOME = ROOT / "home"
shutil.copytree(os.environ["renderedHome"], HOME, symlinks=True)
EMPTY_HOME = ROOT / "empty-home"
EMPTY_HOME.mkdir()
NATIVE_CONFIG = (
    "Library/Preferences/clangd/config.yaml"
    if sys.platform == "darwin"
    else ".config/clangd/config.yaml"
)
assert (HOME / NATIVE_CONFIG).is_file(), "rendered Home Manager policy is missing"
if sys.platform == "darwin":
    assert not (HOME / ".config/clangd/config.yaml").exists(), "stale Darwin XDG policy"


def diagnostics(project, filename, source, flags, home, project_config=None):
    directory = ROOT / project
    directory.mkdir()
    path = directory / filename
    path.write_text(source)
    (directory / "compile_commands.json").write_text(json.dumps([{
        "directory": str(directory),
        "file": str(path),
        "arguments": ["clang", *flags, "-c", str(path)],
    }]))
    if project_config is not None:
        (directory / ".clangd").write_text(project_config)

    environment = os.environ.copy()
    # Never inherit the builder's user policy or XDG overrides.
    for name in list(environment):
        if name.startswith("XDG_") or name == "CLANGD_FLAGS":
            environment.pop(name)
    environment.update(HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"))
    messages = queue.Queue()
    with tempfile.TemporaryFile(mode="w+") as log:
        process = subprocess.Popen(
            [os.environ["clangd"], "--enable-config", "--background-index=false",
             "--clang-tidy=false", "--header-insertion=never", "-j=1"],
            cwd=directory, env=environment, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=log,
        )

        def receive():
            try:
                while True:
                    headers = {}
                    while True:
                        line = process.stdout.readline()
                        if not line:
                            raise EOFError("clangd closed stdout")
                        if line == b"\r\n":
                            break
                        key, value = line.decode().split(":", 1)
                        headers[key.lower()] = value.strip()
                    messages.put(json.loads(process.stdout.read(int(headers["content-length"]))))
            except Exception as error:
                messages.put(error)

        reader = threading.Thread(target=receive, daemon=True)
        reader.start()

        def send(message):
            payload = json.dumps({"jsonrpc": "2.0", **message}).encode()
            process.stdin.write(f"Content-Length: {len(payload)}\r\n\r\n".encode() + payload)
            process.stdin.flush()

        def until(predicate):
            while True:
                message = messages.get(timeout=45)
                if isinstance(message, Exception):
                    raise message
                if predicate(message):
                    return message

        try:
            send({"id": 1, "method": "initialize", "params": {
                "processId": None, "rootUri": directory.as_uri(),
                "capabilities": {"textDocument": {"publishDiagnostics": {"versionSupport": True}}},
            }})
            initialized = until(lambda message: message.get("id") == 1)
            assert "result" in initialized, initialized
            send({"method": "initialized", "params": {}})
            send({"method": "textDocument/didOpen", "params": {"textDocument": {
                "uri": path.as_uri(), "languageId": "c" if filename.endswith(".c") else "cpp",
                "version": 1, "text": source,
            }}})
            published = until(lambda message: (
                message.get("method") == "textDocument/publishDiagnostics"
                and message["params"]["uri"] == path.as_uri()
            ))
            result = published["params"]["diagnostics"]
            send({"id": 2, "method": "shutdown", "params": None})
            until(lambda message: message.get("id") == 2)
            send({"method": "exit", "params": None})
            process.wait(timeout=10)
            assert process.returncode == 0, f"clangd exited {process.returncode}"
            return result
        except Exception:
            log.seek(0)
            print(log.read(), file=sys.stderr)
            raise
        finally:
            if process.poll() is None:
                process.kill()
            process.wait()
            reader.join(timeout=5)
            process.stdin.close()
            process.stdout.close()


CPP23 = """\
#if __cplusplus <= 202002L
#error Project C++23 standard was overridden
#endif
constexpr int project_standard() {
    if consteval { return 23; } else { return 0; }
}
static_assert(project_standard() == 23);
"""
for project, filename, flags, config in [
    ("cdb-cpp23", "standard.cpp", ["-std=c++23"], None),
    ("project-cpp23", "standard.cpp", [], "CompileFlags:\n  Add: [-std=c++23]\n"),
    ("cpp-header", "standard.h", ["-x", "c++-header", "-std=c++23"], None),
]:
    result = diagnostics(project, filename, CPP23, flags, HOME, config)
    assert result == [], f"{project}: expected clean C++23 diagnostics, got {result}"
    print(f"{project}: clean C++23 diagnostics")

WARNING = "int warning_probe(void) { int unused_local; return 0; }\n"
baseline = diagnostics("warning-baseline", "warning.c", WARNING, ["-std=c17"], EMPTY_HOME)
assert baseline == [], f"warning control unexpectedly diagnosed: {baseline}"
configured = diagnostics("warning-policy", "warning.c", WARNING, ["-std=c17"], HOME)
assert any(
    diagnostic.get("code") == "-Wunused-variable" and diagnostic.get("severity") == 2
    for diagnostic in configured
), configured
print(f"{NATIVE_CONFIG}: native policy enables the unused-variable warning")
