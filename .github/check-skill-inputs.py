import base64
import json
import sys
from pathlib import Path
from typing import Any

SKILL_INPUTS = (
    "intel-performance-skills",
    "low-level-dev-skills",
    "rewrite-rs-skills",
    "trailofbits-skills",
)
APPROVALS = Path(".github/reviewed-skill-inputs.json")


# Reject incomplete approval data rather than silently checking fewer inputs.
def read_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise TypeError(f"{path} must contain a JSON object")
    return value


# Compare complete source content identities, not mutable refs or timestamps.
def require_sha256(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.startswith("sha256-"):
        raise ValueError(f"{label} must contain a sha256 SRI hash")
    if len(base64.b64decode(value[7:], validate=True)) != 32:
        raise ValueError(f"{label} must contain a 32-byte sha256 SRI hash")
    return value


def check_skill_inputs() -> None:
    approved = read_object(APPROVALS)
    if set(approved) != set(SKILL_INPUTS):
        raise ValueError(f"{APPROVALS} must approve exactly {SKILL_INPUTS}")
    lock = read_object(Path("flake.lock"))
    nodes = lock["nodes"]
    root_inputs = nodes[lock["root"]]["inputs"]
    changed: list[str] = []
    for name in SKILL_INPUTS:
        node_id = root_inputs[name]
        if not isinstance(node_id, str):
            raise TypeError(f"{name} must reference a directly locked node")
        actual = require_sha256(nodes[node_id]["locked"]["narHash"], name)
        expected = require_sha256(approved[name], f"{name} approval")
        if actual != expected:
            changed.append(name)
    if changed:
        raise ValueError(
            f"Unreviewed skill input contents: {', '.join(changed)}. "
            f"Review the upstream diff, then update {APPROVALS} if approved."
        )


if __name__ == "__main__":
    try:
        check_skill_inputs()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Skill input approval check failed: {error}", file=sys.stderr)
        sys.exit(1)
    print("Locked skill input contents match the reviewed hashes.")
