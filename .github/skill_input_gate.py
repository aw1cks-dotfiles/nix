"""Pure, fail-closed skill-input review policy; no network or executable lock data."""

import base64
import binascii
import re


_SHA = re.compile(r"[0-9a-fA-F]{40}")
_OWNER = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?")
_REPO = re.compile(r"[A-Za-z0-9_.-]+")
_DECISIONS = {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}


def _sha(value: object) -> bool:
    return isinstance(value, str) and _SHA.fullmatch(value) is not None


def _hash(value: object) -> bool:
    if not isinstance(value, str) or not value.startswith("sha256-"):
        return False
    encoded = value[len("sha256-") :]
    try:
        digest = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        return False
    return len(digest) == 32 and base64.b64encode(digest).decode("ascii") == encoded


def _sources(sources: dict) -> list[str]:
    if not isinstance(sources, dict) or not sources:
        raise ValueError("Guarded skill sources must be a nonempty mapping")
    for name, source in sources.items():
        if not isinstance(name, str) or not name or not isinstance(source, dict):
            raise ValueError("Invalid guarded skill source")
        owner, repo = source.get("owner"), source.get("repo")
        if (
            not isinstance(owner, str)
            or not _OWNER.fullmatch(owner)
            or not isinstance(repo, str)
            or not _REPO.fullmatch(repo)
            or repo in {".", ".."}
        ):
            raise ValueError(f"Invalid GitHub source identity for {name}")
    return sorted(sources)


def _locked_inputs(lock: dict, sources: dict, names: list[str]) -> dict:
    if not isinstance(lock, dict) or not isinstance(lock.get("nodes"), dict):
        raise ValueError("Lock must contain a nodes mapping")
    nodes = lock["nodes"]
    root = lock.get("root")
    if not isinstance(root, str) or not root or not isinstance(nodes.get(root), dict):
        raise ValueError("Lock must identify its root node")
    inputs = nodes[root].get("inputs")
    if not isinstance(inputs, dict):
        raise ValueError("Lock root must contain an inputs mapping")
    result = {}
    for name in names:
        node_id = inputs.get(name)
        # Only direct root inputs are supported. Follows paths and a same-named
        # decoy node must never redirect validation away from the real input.
        if not isinstance(node_id, str) or not node_id:
            raise ValueError(f"{name} must reference a direct lock node")
        node = nodes.get(node_id)
        if not isinstance(node, dict) or not isinstance(node.get("locked"), dict):
            raise ValueError(f"Missing locked source for {name}")
        locked = node["locked"]
        source = sources[name]
        if (
            locked.get("type") != "github"
            or locked.get("owner") != source["owner"]
            or locked.get("repo") != source["repo"]
            or not _sha(locked.get("rev"))
            or not _hash(locked.get("narHash"))
        ):
            raise ValueError(f"Invalid pinned GitHub source for {name}")
        result[name] = dict(locked)
    return result


def _approvers(reviews: list[dict], permissions: dict[str, str], head_sha: str) -> list[str]:
    if not isinstance(reviews, list) or not isinstance(permissions, dict):
        raise ValueError("Reviews and collaborator permissions must be collections")
    latest = {}
    seen = set()
    for review in reviews:
        if not isinstance(review, dict):
            raise ValueError("Invalid review record")
        user = review.get("user")
        if not isinstance(user, dict) or user.get("type") != "User":
            continue
        login = user.get("login")
        if not isinstance(login, str) or not login:
            raise ValueError("Human review must identify its author")
        permission = permissions.get(login)
        if not isinstance(permission, str) or permission not in {"write", "maintain", "admin"}:
            continue
        state = review.get("state")
        if not isinstance(state, str):
            raise ValueError(f"Invalid review decision for {login}")
        if state in {"COMMENTED", "PENDING"}:
            continue
        if state not in _DECISIONS:
            raise ValueError(f"Unknown review decision for {login}")
        review_id = review.get("id")
        if type(review_id) is not int or review_id <= 0 or review_id in seen:
            raise ValueError("Review decisions require unique positive integer IDs")
        seen.add(review_id)
        if not _sha(review.get("commit_id")):
            raise ValueError(f"Review decision must identify its commit for {login}")
        previous = latest.get(login)
        if previous is None or review_id > previous["id"]:
            latest[login] = review
    return sorted(
        login
        for login, review in latest.items()
        if review["state"] == "APPROVED" and review["commit_id"] == head_sha
    )


def evaluate(
    base_lock: dict,
    head_lock: dict,
    reviews: list[dict],
    permissions: dict[str, str],
    sources: dict,
    head_sha: str,
) -> dict:
    """Return approval, sorted content changes, and authorized current approvers.

    Malformed policy inputs raise ValueError, even without content drift or with
    an approving review. Callers must treat errors as a closed gate. Review IDs
    determine decision order, independently of pagination or timestamp ties.
    COMMENTED/PENDING reviews do not revoke a decision; dismissal and requests
    for changes do. The caller must exclude the pull request author.
    """
    names = _sources(sources)
    if not _sha(head_sha):
        raise ValueError("Current PR head must be a pinned commit SHA")
    before = _locked_inputs(base_lock, sources, names)
    after = _locked_inputs(head_lock, sources, names)
    changes = [
        {"name": name, "before": before[name], "after": after[name]}
        for name in names
        if before[name]["narHash"] != after[name]["narHash"]
    ]
    approvers = _approvers(reviews, permissions, head_sha)
    return {"approved": not changes or bool(approvers), "changes": changes, "approvers": approvers}
