import base64
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import sys
from urllib.parse import parse_qs, urlsplit

import pytest

sys.path.insert(0, str(Path(__file__).parent))
SPEC = importlib.util.spec_from_file_location(
    "skill_input_review", Path(__file__).with_name("skill_input_review.py")
)
REVIEW = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REVIEW)

HEAD = "a" * 40
BASE = "b" * 40
NEXT = "c" * 40
SOURCES = {"skill": {"owner": "upstream", "repo": "skills"}}


def approval(login="maintainer", kind="User", identifier=1):
    return {"id": identifier, "user": {"login": login, "type": kind},
            "state": "APPROVED", "commit_id": HEAD}


class State(REVIEW.GitHub):
    """Stateful API transport: exercise policy/report transitions, not live writes."""

    def __init__(self):
        self.repo = "owner/repository"
        self.server = "https://github.com"
        self.current = {"number": 17, "state": "open", "user": {"login": "author"},
                        "head": {"sha": HEAD},
                        "base": {"sha": BASE, "ref": "main", "repo": {"full_name": self.repo}}}
        self.locks = {}
        for sha, byte in ((BASE, b"a"), (HEAD, b"b")):
            self.locks[sha] = {"root": "root", "nodes": {
                "root": {"inputs": {"skill": "alias"}},
                "alias": {"locked": {"type": "github", **SOURCES["skill"],
                                     "rev": sha, "narHash": "sha256-" + base64.b64encode(byte * 32).decode()}}}}
        self.reviews = []
        self.comments = []
        self.statuses = []
        self.roles = {"maintainer": "admin", "author": "admin", "visitor": "read"}
        self.permission_error = False

    def request(self, path, method="GET", data=None):
        url = urlsplit(path)
        suffix = url.path.removeprefix(self.path(""))
        query = parse_qs(url.query)
        if suffix == "pulls/17":
            return deepcopy(self.current)
        if suffix == "contents/flake.lock":
            lock = self.locks[query["ref"][0]]
            return {"type": "file", "encoding": "base64",
                    "content": base64.b64encode(json.dumps(lock).encode()).decode()}
        if suffix == f"commits/{HEAD}/pulls":
            return [{"number": 17}]
        if suffix == "pulls/17/commits":
            return [{"sha": HEAD}]
        if suffix in ("pulls/17/reviews", "issues/17/comments") and method == "GET":
            rows = self.reviews if suffix.endswith("reviews") else self.comments
            start = (int(query["page"][0]) - 1) * 100
            return deepcopy(rows[start:start + 100])
        if suffix.startswith("collaborators/"):
            if self.permission_error:
                raise REVIEW.ReviewError("Permission lookup unavailable")
            return {"permission": self.roles.get(suffix.split("/")[1], "read")}
        if suffix.startswith("statuses/") and method == "POST":
            self.statuses.append((suffix.split("/")[1], deepcopy(data)))
            return data
        if suffix == "issues/17/comments" and method == "POST":
            self.comments.append({"id": len(self.comments) + 1, "body": data["body"],
                                  "user": {"login": "github-actions[bot]", "type": "Bot"}})
            return self.comments[-1]
        if suffix.startswith("issues/comments/"):
            identifier = int(suffix.split("/")[-1])
            if method == "PATCH":
                next(row for row in self.comments if row["id"] == identifier).update(data)
                return data
            if method == "DELETE":
                self.comments = [row for row in self.comments if row["id"] != identifier]
                return None
        raise AssertionError((path, method))


@pytest.fixture
def state(monkeypatch):
    monkeypatch.setattr(REVIEW, "load_sources", lambda: SOURCES)
    # These cases concern authorization races and API state; the real Git source
    # fetch/diff path is exercised separately against upstream commits.
    monkeypatch.setattr(REVIEW, "upstream_diffs", lambda *args: [])
    return State()


def report(state, tmp_path):
    REVIEW.report_pull(state, 17, SOURCES, "https://github.com/owner/repository/actions/runs/1", tmp_path / "diff.patch")
    return state.statuses[-1][1]["state"]


def test_approval_and_dismissal_transition_the_same_report(state, tmp_path):
    assert report(state, tmp_path) == "pending"
    state.reviews = [approval()]
    assert report(state, tmp_path) == "success"
    state.reviews[0]["state"] = "DISMISSED"
    assert report(state, tmp_path) == "pending"
    assert len(state.comments) == 1


def test_author_bot_and_read_only_reviews_cannot_authorize(state, tmp_path):
    state.reviews = [approval("author"), approval("visitor", identifier=2),
                     approval("automation[bot]", "Bot", 3)]
    assert report(state, tmp_path) == "pending"


def test_approval_beyond_first_api_page_is_considered(state, tmp_path):
    state.reviews = [approval("automation[bot]", "Bot", index + 1) for index in range(100)]
    state.reviews.append(approval(identifier=101))
    assert report(state, tmp_path) == "success"


def test_sticky_comment_search_pages_and_rejects_user_spoof(state, tmp_path):
    spoof = {"id": 1, "body": REVIEW.MARKER + " forged", "user": {"login": "author", "type": "User"}}
    state.comments = [spoof] + [{"id": index + 2, "body": "unrelated", "user": {}} for index in range(99)]
    state.comments.append({"id": 101, "body": REVIEW.MARKER + " old", "user": {"login": "github-actions[bot]", "type": "Bot"}})
    report(state, tmp_path)
    assert len(state.comments) == 101
    assert state.comments[0] == spoof
    assert "Awaiting human approval" in state.comments[-1]["body"]


def test_diff_failure_revokes_previous_success(state, tmp_path, monkeypatch):
    state.reviews = [approval()]
    assert report(state, tmp_path) == "success"

    def unavailable(*args):
        raise REVIEW.ReviewError("Upstream fetch unavailable")

    monkeypatch.setattr(REVIEW, "upstream_diffs", unavailable)
    with pytest.raises(REVIEW.ReviewError):
        report(state, tmp_path)
    assert state.statuses[-1][1]["state"] == "error"


def test_permission_lookup_failure_revokes_previous_success(state, tmp_path):
    state.reviews = [approval()]
    assert report(state, tmp_path) == "success"
    state.permission_error = True
    with pytest.raises(REVIEW.ReviewError):
        report(state, tmp_path)
    assert state.statuses[-1][1]["state"] == "error"


def test_dismissal_during_source_fetch_is_rechecked(state, tmp_path, monkeypatch):
    state.reviews = [approval()]

    def dismiss(*args):
        state.reviews[0]["state"] = "DISMISSED"
        return []

    monkeypatch.setattr(REVIEW, "upstream_diffs", dismiss)
    assert report(state, tmp_path) == "pending"
    assert all(status[1]["state"] != "success" for status in state.statuses)


def test_head_movement_during_source_fetch_never_authorizes_new_head(state, tmp_path, monkeypatch):
    state.reviews = [approval()]

    def push(*args):
        state.current["head"]["sha"] = NEXT
        return []

    monkeypatch.setattr(REVIEW, "upstream_diffs", push)
    with pytest.raises(REVIEW.ReviewError):
        report(state, tmp_path)
    assert state.statuses[-1][0] == NEXT
    assert state.statuses[-1][1]["state"] == "error"
    assert all(status[1]["state"] != "success" for status in state.statuses)


def test_stale_gate_event_fails_closed_before_authorizing(state, tmp_path, monkeypatch):
    output = tmp_path / "output"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output))
    event = {"pull_request": deepcopy(state.current)}
    state.current["head"]["sha"] = NEXT
    with pytest.raises(REVIEW.ReviewError):
        REVIEW.gate(state, event, "pull_request_review")
    assert output.read_text().splitlines()[-1] == "approved=false"
    assert state.statuses == []


def test_unreviewed_gate_is_pending_not_a_command_failure(state, tmp_path, monkeypatch):
    output = tmp_path / "output"
    monkeypatch.setenv("GITHUB_OUTPUT", str(output))
    REVIEW.gate(state, {"pull_request": state.current}, "pull_request")
    assert output.read_text().splitlines()[-1] == "approved=false"


def test_no_drift_needs_no_review(state, tmp_path):
    state.locks[HEAD] = deepcopy(state.locks[BASE])
    assert report(state, tmp_path) == "success"


def test_comment_neutralizes_upstream_markup_and_mentions(state):
    result = REVIEW.evaluate_pull(state, state.current, SOURCES)
    malicious = "</pre><img src=x onerror=alert(1)>\n@maintainer\n<!-- skill-input-review -->"
    body = REVIEW.comment_body(state.current, result, [{"change": result["changes"][0],
        "stat": malicious, "excerpt": malicious, "truncated": False}], "https://github.com/owner/repository/actions/runs/1")
    assert "<img src=x" not in body
    assert "@maintainer" not in body
    assert body.count(REVIEW.MARKER) == 1
    assert "&lt;/pre&gt;" in body


def relay(state, candidates):
    return {"workflow_run": {"name": "CI", "head_sha": HEAD,
            "repository": {"full_name": state.repo}, "pull_requests": candidates}}


def test_empty_relay_association_uses_github_commit_membership(state):
    assert REVIEW.report_numbers(state, relay(state, []), "workflow_run") == [17]


def test_relay_for_older_head_recomputes_current_pr_not_event_approval(state):
    state.current["head"]["sha"] = NEXT
    assert REVIEW.report_numbers(state, relay(state, [{"number": 17}]), "workflow_run") == [17]
    assert state.statuses == []


def test_unrelated_workflow_commit_cannot_route_to_pr(state):
    event = relay(state, [{"number": 17}])
    event["workflow_run"]["head_sha"] = NEXT
    assert REVIEW.report_numbers(state, event, "workflow_run") == []


def test_foreign_repository_relay_cannot_mutate_status(state):
    event = relay(state, [{"number": 17}])
    event["workflow_run"]["repository"]["full_name"] = "attacker/repository"
    with pytest.raises(REVIEW.ReviewError):
        REVIEW.route(state, event, "workflow_run", "1")
    assert state.statuses == []


def test_artifact_creation_failure_revokes_existing_success(state, tmp_path, monkeypatch):
    state.reviews = [approval()]
    assert report(state, tmp_path) == "success"
    # Opening a directory as the artifact fails before any diff is fetched.
    monkeypatch.setattr(REVIEW, "PATCH_PATH", tmp_path)
    event = {"pull_request": state.current}
    with pytest.raises(OSError):
        REVIEW.report(state, event, "pull_request_target", "1", selected=17)
    assert state.statuses[-1][1]["state"] == "error"
