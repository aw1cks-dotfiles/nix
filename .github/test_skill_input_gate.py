import base64
from copy import deepcopy
import importlib.util
from pathlib import Path

import pytest

# Resolve relative to this file, including when both files are copied into the
# Nix store and the checkout is not on sys.path.
SPEC = importlib.util.spec_from_file_location(
    "skill_input_gate", Path(__file__).with_name("skill_input_gate.py")
)
assert SPEC is not None and SPEC.loader is not None
POLICY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POLICY)
evaluate = POLICY.evaluate

INPUTS = (
    "intel-performance-skills",
    "low-level-dev-skills",
    "rewrite-rs-skills",
    "trailofbits-skills",
)
HEAD = "a" * 40
OLD_HEAD = "b" * 40
NEW_HASH = "sha256-" + base64.b64encode(bytes([7]) * 32).decode()


@pytest.fixture
def policy():
    sources = {
        name: {"owner": f"owner-{index}", "repo": name}
        for index, name in enumerate(INPUTS)
    }
    nodes = {
        "entry": {"inputs": {name: f"source-{name}" for name in INPUTS}},
        "unrelated": {"locked": {"narHash": "unrelated-before"}},
    }
    for index, name in enumerate(INPUTS):
        nodes[f"source-{name}"] = {
            "locked": {
                "type": "github",
                **sources[name],
                "rev": str(index) * 40,
                "narHash": "sha256-" + base64.b64encode(bytes([index]) * 32).decode(),
            }
        }
    base = {"version": 7, "root": "entry", "nodes": nodes}
    return {
        "base_lock": base,
        "head_lock": deepcopy(base),
        "reviews": [],
        "permissions": {},
        "sources": sources,
        "head_sha": HEAD,
    }


def locked(policy, name=INPUTS[0], side="head_lock"):
    return policy[side]["nodes"][f"source-{name}"]["locked"]


def review(identifier=1, login="maintainer", state="APPROVED", commit=HEAD, kind="User"):
    return {
        "id": identifier,
        "user": {"login": login, "type": kind},
        "state": state,
        "commit_id": commit,
    }


def drift(policy):
    locked(policy)["narHash"] = NEW_HASH
    return policy


@pytest.mark.parametrize("name", INPUTS)
def test_content_change_requires_review_even_at_identical_revision(policy, name):
    locked(policy, name)["narHash"] = NEW_HASH
    result = evaluate(**policy)
    assert result == {
        "approved": False,
        "changes": [{
            "name": name,
            "before": locked(policy, name, "base_lock"),
            "after": locked(policy, name),
        }],
        "approvers": [],
    }


def test_identical_contents_at_another_revision_need_no_review(policy):
    locked(policy)["rev"] = "f" * 40
    assert evaluate(**policy) == {"approved": True, "changes": [], "approvers": []}


def test_unrelated_maintenance_is_not_guarded(policy):
    policy["head_lock"]["nodes"]["unrelated"]["locked"]["narHash"] = "after"
    assert evaluate(**policy)["approved"] is True


def test_direct_aliases_resolve_actual_node_not_same_named_decoy(policy):
    drift(policy)
    for side in ("base_lock", "head_lock"):
        policy[side]["nodes"][INPUTS[0]] = {"locked": {"narHash": "decoy"}}
    assert evaluate(**policy)["approved"] is False


def test_change_records_and_approvers_are_sorted_and_inputs_are_not_mutated(policy):
    for name in reversed(INPUTS):
        locked(policy, name)["narHash"] = NEW_HASH
    policy["sources"] = dict(reversed(list(policy["sources"].items())))
    policy["reviews"] = [review(2, "zoe"), review(1, "amy")]
    policy["permissions"] = {"zoe": "admin", "amy": "write"}
    before = deepcopy(policy)
    result = evaluate(**policy)
    assert policy == before
    assert result["approved"] is True
    assert result["approvers"] == ["amy", "zoe"]
    assert [change["name"] for change in result["changes"]] == sorted(INPUTS)
    result["changes"][0]["after"]["rev"] = "changed by consumer"
    assert policy == before


@pytest.mark.parametrize("side", ["base_lock", "head_lock"])
@pytest.mark.parametrize("name", INPUTS)
@pytest.mark.parametrize("problem", [
    "missing_input", "missing_node", "missing_locked", "follows", "node_alias",
    "wrong_owner", "wrong_repo", "wrong_type", "missing_owner", "missing_repo",
    "missing_rev", "missing_hash",
])
def test_all_guarded_inputs_are_validated_on_both_sides(policy, side, name, problem):
    # Even an approval and no content drift must not bypass validation.
    policy["reviews"] = [review()]
    policy["permissions"] = {"maintainer": "write"}
    lock = policy[side]
    source = locked(policy, name, side)
    if problem == "missing_input":
        del lock["nodes"]["entry"]["inputs"][name]
    elif problem == "missing_node":
        del lock["nodes"][f"source-{name}"]
    elif problem == "missing_locked":
        del lock["nodes"][f"source-{name}"]["locked"]
    elif problem == "follows":
        lock["nodes"]["entry"]["inputs"][name] = ["another", name]
    elif problem == "node_alias":
        lock["nodes"][f"source-{name}"] = {"inputs": {name: "other"}}
    elif problem.startswith("missing_"):
        del source[{"missing_hash": "narHash"}.get(problem, problem[8:])]
    else:
        source[{"wrong_owner": "owner", "wrong_repo": "repo", "wrong_type": "type"}[problem]] = "unexpected"
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("side", ["base_lock", "head_lock"])
@pytest.mark.parametrize("bad", [None, [], {}, {"nodes": []}, {"nodes": {}, "root": "absent"},
    {"nodes": {"root": {"inputs": []}}, "root": "root"},
    {"nodes": {"root": {}}, "root": ["root"]}])
def test_malformed_lock_documents_fail_closed(policy, side, bad):
    policy[side] = bad
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("side", ["base_lock", "head_lock"])
@pytest.mark.parametrize("bad_hash", [None, 123, "", "sha256-not-base64", "sha256-YQ==",
    "sha512-" + "A" * 44, "sha256-" + "A" * 43 + "=\n",
    "sha256-" + "A" * 42 + "B=", "sha256-" + "A" * 44])
def test_invalid_hash_fails_closed_even_without_drift(policy, side, bad_hash):
    locked(policy, side=side)["narHash"] = bad_hash
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("side", ["base_lock", "head_lock"])
@pytest.mark.parametrize("bad_rev", [None, 1, "", "main", "a" * 39, "g" * 40, "a" * 40 + "\n"])
def test_invalid_pinned_revision_fails_closed(policy, side, bad_rev):
    locked(policy, side=side)["rev"] = bad_rev
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("sources", [None, [], {}, {"skill": None}, {"": {"owner": "ok", "repo": "ok"}},
    {"skill": {}}, {"skill": {"owner": "../evil", "repo": "ok"}},
    {"skill": {"owner": "ok", "repo": "../evil"}},
    {"skill": {"owner": "ok", "repo": ".."}},
    {"skill": {"owner": None, "repo": "ok"}},
    {"skill": {"owner": "ok", "repo": 12}}])
def test_invalid_source_allowlists_fail_closed(policy, sources):
    policy["sources"] = sources
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("sha", [None, "", "main", "a" * 39, "z" * 40])
def test_current_head_must_be_exact_sha(policy, sha):
    policy["head_sha"] = sha
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("permission", ["write", "maintain", "admin"])
def test_authorized_approval_for_exact_head_unblocks_drift(policy, permission):
    drift(policy)
    policy["reviews"] = [review()]
    policy["permissions"] = {"maintainer": permission}
    assert evaluate(**policy)["approved"] is True
    assert evaluate(**policy)["approvers"] == ["maintainer"]


@pytest.mark.parametrize("permission", [None, "read", "triage", "Write", "unknown"])
def test_unauthorized_reviews_do_not_approve(policy, permission):
    drift(policy)
    policy["reviews"] = [review()]
    policy["permissions"] = {"maintainer": permission}
    assert evaluate(**policy)["approved"] is False


@pytest.mark.parametrize("kind", ["Bot", "Organization", None])
def test_nonhuman_reviews_do_not_approve(policy, kind):
    drift(policy)
    policy["reviews"] = [review(kind=kind)]
    policy["permissions"] = {"maintainer": "admin"}
    assert evaluate(**policy)["approved"] is False


def test_approval_of_previous_head_does_not_approve_current_head(policy):
    drift(policy)
    policy["reviews"] = [review(commit=OLD_HEAD)]
    policy["permissions"] = {"maintainer": "write"}
    assert evaluate(**policy)["approved"] is False


@pytest.mark.parametrize("state", ["DISMISSED", "CHANGES_REQUESTED"])
@pytest.mark.parametrize("reverse", [False, True])
def test_later_decisions_revoke_prior_approval_independent_of_api_order(policy, state, reverse):
    drift(policy)
    reviews = [review(1), review(2, state=state)]
    policy["reviews"] = list(reversed(reviews)) if reverse else reviews
    policy["permissions"] = {"maintainer": "write"}
    assert evaluate(**policy)["approved"] is False


def test_dismissed_review_cannot_authorize(policy):
    drift(policy)
    policy["reviews"] = [review(state="DISMISSED")]
    policy["permissions"] = {"maintainer": "admin"}
    assert evaluate(**policy)["approvers"] == []


def test_superseding_approval_on_other_commit_cannot_reuse_older_current_approval(policy):
    drift(policy)
    policy["reviews"] = [review(2, commit=OLD_HEAD), review(1)]
    policy["permissions"] = {"maintainer": "write"}
    assert evaluate(**policy)["approved"] is False


def test_new_current_approval_supersedes_changes_requested(policy):
    drift(policy)
    policy["reviews"] = [review(2), review(1, state="CHANGES_REQUESTED")]
    policy["permissions"] = {"maintainer": "write"}
    assert evaluate(**policy)["approved"] is True


@pytest.mark.parametrize("state", ["COMMENTED", "PENDING"])
def test_nondecision_does_not_revoke_approval(policy, state):
    drift(policy)
    policy["reviews"] = [review(1), review(2, state=state)]
    policy["permissions"] = {"maintainer": "write"}
    assert evaluate(**policy)["approved"] is True


def test_other_users_requests_do_not_override_authorized_approver(policy):
    drift(policy)
    policy["reviews"] = [review(1), review(2, login="other", state="CHANGES_REQUESTED")]
    policy["permissions"] = {"maintainer": "write", "other": "write"}
    assert evaluate(**policy)["approvers"] == ["maintainer"]


@pytest.mark.parametrize("field,value", [
    ("id", None), ("id", True), ("id", 0), ("id", "1"),
    ("state", "UNKNOWN"), ("commit_id", None), ("commit_id", "main"),
    ("state", []), ("state", None), ("commit_id", []),
    ("user", {"type": "User", "login": ""}),
])
def test_malformed_authorized_decisions_fail_closed(policy, field, value):
    policy["reviews"] = [review()]
    policy["reviews"][0][field] = value
    policy["permissions"] = {"maintainer": "write"}
    with pytest.raises(ValueError):
        evaluate(**policy)


@pytest.mark.parametrize("field,value", [("reviews", {}), ("reviews", [None]), ("permissions", [])])
def test_invalid_review_collections_fail_closed(policy, field, value):
    policy[field] = value
    with pytest.raises(ValueError):
        evaluate(**policy)


def test_conflicting_duplicate_review_ids_fail_closed(policy):
    policy["reviews"] = [review(), review(state="DISMISSED")]
    policy["permissions"] = {"maintainer": "write"}
    with pytest.raises(ValueError):
        evaluate(**policy)
