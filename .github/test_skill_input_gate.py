import base64
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

CHECK = Path(__file__).with_name("check-skill-inputs.py")
INPUTS = ("intel-performance-skills", "low-level-dev-skills")
NEW_HASH = "sha256-" + base64.b64encode(bytes([7]) * 32).decode()


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value), encoding="utf-8")


@pytest.fixture
def repository(tmp_path: Path) -> Path:
    approvals = {
        name: "sha256-" + base64.b64encode(bytes([index]) * 32).decode()
        for index, name in enumerate(INPUTS)
    }
    # Node IDs need not match input names, and the lock root is not fixed.
    nodes: dict[str, Any] = {
        "entry": {"inputs": {name: f"source-{name}" for name in INPUTS}},
        "unrelated": {"locked": {"narHash": "unrelated-before"}},
    }
    nodes.update(
        {
            f"source-{name}": {"locked": {"narHash": digest, "rev": "before"}}
            for name, digest in approvals.items()
        }
    )
    (tmp_path / ".github").mkdir()
    save(tmp_path / "flake.lock", {"root": "entry", "nodes": nodes})
    save(tmp_path / ".github/reviewed-skill-inputs.json", approvals)
    return tmp_path


def run_gate(repository: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(CHECK)],
        cwd=repository,
        capture_output=True,
        text=True,
        check=False,
    )


# Exit status is the CI gate's public contract.
def test_unrelated_maintenance_does_not_require_skill_approval(
    repository: Path,
) -> None:
    lock = load(repository / "flake.lock")
    lock["nodes"]["unrelated"]["locked"]["narHash"] = "unrelated-after"
    save(repository / "flake.lock", lock)
    assert run_gate(repository).returncode == 0


@pytest.mark.parametrize("name", INPUTS)
def test_changed_contents_fail_even_when_revision_is_unchanged(
    repository: Path,
    name: str,
) -> None:
    lock = load(repository / "flake.lock")
    lock["nodes"][f"source-{name}"]["locked"]["narHash"] = NEW_HASH
    save(repository / "flake.lock", lock)
    result = run_gate(repository)
    assert result.returncode == 1
    assert name in result.stderr


def test_reviewing_new_contents_unblocks_the_gate(repository: Path) -> None:
    name = INPUTS[0]
    lock = load(repository / "flake.lock")
    lock["nodes"][f"source-{name}"]["locked"]["narHash"] = NEW_HASH
    save(repository / "flake.lock", lock)
    assert run_gate(repository).returncode == 1

    approvals_path = repository / ".github/reviewed-skill-inputs.json"
    approvals = load(approvals_path)
    approvals[name] = NEW_HASH
    save(approvals_path, approvals)
    assert run_gate(repository).returncode == 0


def test_identical_contents_at_another_revision_remain_approved(
    repository: Path,
) -> None:
    lock = load(repository / "flake.lock")
    lock["nodes"][f"source-{INPUTS[0]}"]["locked"]["rev"] = "after"
    save(repository / "flake.lock", lock)
    assert run_gate(repository).returncode == 0


@pytest.mark.parametrize("name", INPUTS)
def test_missing_approval_fails_closed(repository: Path, name: str) -> None:
    path = repository / ".github/reviewed-skill-inputs.json"
    approvals = load(path)
    del approvals[name]
    save(path, approvals)
    assert run_gate(repository).returncode == 1


@pytest.mark.parametrize("name", INPUTS)
def test_missing_locked_input_fails_closed(
    repository: Path, name: str
) -> None:
    lock = load(repository / "flake.lock")
    del lock["nodes"]["entry"]["inputs"][name]
    save(repository / "flake.lock", lock)
    assert run_gate(repository).returncode == 1


@pytest.mark.parametrize(
    "bad_hash", [None, "", "sha256-not-base64", "sha256-YQ=="]
)
def test_invalid_hash_cannot_be_approved(
    repository: Path,
    bad_hash: str | None,
) -> None:
    name = INPUTS[0]
    approvals_path = repository / ".github/reviewed-skill-inputs.json"
    approvals = load(approvals_path)
    approvals[name] = bad_hash
    save(approvals_path, approvals)
    lock = load(repository / "flake.lock")
    lock["nodes"][f"source-{name}"]["locked"]["narHash"] = bad_hash
    save(repository / "flake.lock", lock)
    assert run_gate(repository).returncode == 1


@pytest.mark.parametrize("document", ["{", "{}", "[]"])
def test_invalid_approval_document_cannot_disable_gate(
    repository: Path,
    document: str,
) -> None:
    (repository / ".github/reviewed-skill-inputs.json").write_text(
        document, encoding="utf-8"
    )
    assert run_gate(repository).returncode == 1
