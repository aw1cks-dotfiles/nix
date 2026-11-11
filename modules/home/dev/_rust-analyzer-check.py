"""Resolve a standard-library definition with the real shared analyzer."""

import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import tempfile
import threading
from urllib.parse import unquote, urlparse


ROOT = Path(os.environ["TMPDIR"]).resolve() / "rust-analyzer-check"
ROOT.mkdir()
# Direct definitions do not require registry dependencies behind std re-exports.
SOURCE = (
    "pub fn value() -> u32 { std::process::id() }\n"
    "pub fn width() -> usize { core::mem::size_of::<u32>() }\n"
)


def definition(name, compiler, expected_sources, explicit_sources=None):
    project = ROOT / name
    project.mkdir()
    (project / "Cargo.toml").write_text(
        '[package]\nname = "source_probe"\nversion = "0.1.0"\nedition = "2021"\n'
        '[lib]\npath = "lib.rs"\n'
    )
    path = project / "lib.rs"
    path.write_text(SOURCE)
    home = project / "home"
    home.mkdir()
    environment = os.environ.copy()
    for key in list(environment):
        if key.startswith(("RUST", "CARGO_", "XDG_")):
            environment.pop(key)
    environment.update(
        HOME=str(home), RUSTUP_HOME=str(home / ".rustup"),
        CARGO_HOME=str(home / ".cargo"), CARGO_NET_OFFLINE="true",
        RUSTUP_AUTO_INSTALL="0", RUSTC=compiler, CARGO=os.environ["cargo"],
        PATH=f'{Path(compiler).parent}:{Path(os.environ["cargo"]).parent}:/usr/bin:/bin',
    )
    if explicit_sources is not None:
        environment["RUST_SRC_PATH"] = explicit_sources
    messages = queue.Queue()
    with tempfile.TemporaryFile(mode="w+") as log:
        process = subprocess.Popen(
            [os.environ["analyzer"]], cwd=project, env=environment,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log,
        )

        def receive():
            try:
                while True:
                    headers = {}
                    while True:
                        line = process.stdout.readline()
                        if not line:
                            raise EOFError("rust-analyzer closed stdout")
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
                message = messages.get(timeout=60)
                if isinstance(message, Exception):
                    raise message
                if predicate(message):
                    return message

        try:
            send({"id": 1, "method": "initialize", "params": {
                "processId": None, "rootUri": project.as_uri(),
                "capabilities": {"experimental": {"serverStatusNotification": True}},
                "initializationOptions": {
                    "cargo": {"buildScripts": {"enable": False}},
                    "procMacro": {"enable": False}, "checkOnSave": False,
                    "cachePriming": {"enable": False},
                },
            }})
            initialized = until(lambda message: message.get("id") == 1)
            assert "result" in initialized, initialized
            send({"method": "initialized", "params": {}})
            send({"method": "textDocument/didOpen", "params": {"textDocument": {
                "uri": path.as_uri(), "languageId": "rust", "version": 1, "text": SOURCE,
            }}})
            until(lambda message: (
                message.get("method") == "experimental/serverStatus"
                and message["params"].get("quiescent") is True
            ))
            # Aggregated toolchains contain real directories with symlinked
            # source files; compare the analyzer's logical source paths.
            expected = Path(expected_sources)
            for request_id, (line, symbol) in enumerate([(0, "id"), (1, "size_of")], start=2):
                send({"id": request_id, "method": "textDocument/definition", "params": {
                    "textDocument": {"uri": path.as_uri()},
                    "position": {"line": line, "character": SOURCE.splitlines()[line].index(symbol) + 1},
                }})
                response = until(lambda message: message.get("id") == request_id)
                locations = response.get("result") or []
                if isinstance(locations, dict):
                    locations = [locations]
                targets = [
                    Path(unquote(urlparse(location.get("targetUri", location.get("uri"))).path))
                    for location in locations
                ]
                assert any(target.is_relative_to(expected) for target in targets), (name, symbol, expected, response)
            print(f"{name}: std/core definitions resolve inside {expected}")
            send({"id": 4, "method": "shutdown", "params": None})
            until(lambda message: message.get("id") == 4)
            send({"method": "exit", "params": None})
            process.wait(timeout=10)
            assert process.returncode == 0, process.returncode
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


definition("nixpkgs-fallback", os.environ["compiler"], os.environ["fallbackSources"])
definition("project-sources", os.environ["sourcedCompiler"], os.environ["toolchainSources"])
definition("explicit-sources", os.environ["sourcedCompiler"], os.environ["fallbackSources"],
           explicit_sources=os.environ["fallbackSources"])
