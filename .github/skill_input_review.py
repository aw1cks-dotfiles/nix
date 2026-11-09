"""Read-only build gate and trusted GitHub skill-input review reporter.

The reporter must run from the default branch, serialized by workflow concurrency.
No PR checkout, lock expression, upstream file, or Git hook is ever executed.
"""

import argparse
import base64
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from skill_input_gate import evaluate


MARKER = "<!-- skill-input-review -->"
STATUS_CONTEXT = "skill-input-review"
PATCH_PATH = Path("skill-input-diff.patch")
SHA = re.compile(r"[0-9a-fA-F]{40}\Z")
REPO = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*\Z")
SOURCE_PART = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*\Z")


class ReviewError(Exception):
    """Untrusted/missing input or a failed external operation."""


def object_value(value, label):
    if not isinstance(value, dict):
        raise ReviewError(f"{label} must be an object")
    return value


def sha_value(value):
    if not isinstance(value, str) or not SHA.fullmatch(value):
        raise ReviewError("Expected a pinned 40-hex commit SHA")
    return value.lower()


def number_value(value):
    if type(value) is not int or value <= 0:
        raise ReviewError("Expected a positive pull request number")
    return value


def read_json(path):
    return object_value(json.loads(Path(path).read_text(encoding="utf-8")), str(path))


class NoRedirect(HTTPRedirectHandler):
    # Never forward the authorization header to a URL from a response.
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ReviewError("Unexpected GitHub API redirect")


class GitHub:
    def __init__(self, repo, token, server="https://github.com"):
        if not REPO.fullmatch(repo):
            raise ReviewError("GH_REPO must be owner/repository")
        parsed = urlsplit(server)
        if parsed.scheme != "https" or not parsed.netloc or parsed.path not in ("", "/") or parsed.query or parsed.fragment or parsed.username:
            raise ReviewError("GITHUB_SERVER_URL must be an HTTPS server origin")
        if not token:
            raise ReviewError("GH_TOKEN is required")
        self.repo = repo
        self.server = server.rstrip("/")
        self.api = "https://api.github.com" if self.server == "https://github.com" else self.server + "/api/v3"
        self.token = token
        self.opener = build_opener(NoRedirect())

    def request(self, path, method="GET", data=None):
        if not path.startswith("/repos/" ) or path.startswith("//"):
            raise ReviewError("Unexpected GitHub API path")
        body = None if data is None else json.dumps(data).encode("utf-8")
        request = Request(self.api + path, data=body, method=method, headers={
            "Authorization": "Bearer " + self.token,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
            "User-Agent": "skill-input-review",
        })
        try:
            with self.opener.open(request, timeout=60) as response:
                payload = response.read()
                return json.loads(payload) if payload else None
        except HTTPError as error:
            raise ReviewError(f"GitHub API {method} failed with HTTP {error.code}") from None
        except URLError:
            raise ReviewError("GitHub API connection failed") from None

    def path(self, suffix):
        return f"/repos/{self.repo}/{suffix}"

    def pages(self, suffix):
        page = 1
        while True:
            separator = "&" if "?" in suffix else "?"
            result = self.request(self.path(f"{suffix}{separator}per_page=100&page={page}"))
            if not isinstance(result, list) or any(not isinstance(item, dict) for item in result):
                raise ReviewError("GitHub list endpoint returned malformed data")
            yield from result
            if len(result) < 100:
                break
            page += 1

    def pull(self, number):
        pull = object_value(self.request(self.path(f"pulls/{number_value(number)}")), "pull request")
        if pull["number"] != number or pull["base"]["repo"]["full_name"].lower() != self.repo.lower():
            raise ReviewError("Pull request does not belong to GH_REPO")
        sha_value(pull["head"]["sha"])
        sha_value(pull["base"]["sha"])
        if not isinstance(pull["user"]["login"], str):
            raise ReviewError("Pull request author is missing")
        return pull

    def lock(self, sha):
        contents = object_value(self.request(self.path("contents/flake.lock?" + urlencode({"ref": sha_value(sha)}))), "lock contents")
        if contents.get("type") != "file" or contents.get("encoding") != "base64":
            raise ReviewError("flake.lock must be a base64-encoded regular file")
        encoded = contents["content"]
        if not isinstance(encoded, str):
            raise ReviewError("Malformed lock file content")
        raw = base64.b64decode("".join(encoded.split()), validate=True)
        return object_value(json.loads(raw), "flake.lock")


def load_sources():
    sources = read_json(Path(__file__).with_name("skill-inputs.json"))
    if not sources:
        raise ReviewError("Skill source allowlist is empty")
    for name, source in sources.items():
        if not isinstance(name, str) or not SOURCE_PART.fullmatch(name):
            raise ReviewError("Invalid guarded input name")
        object_value(source, "guarded source")
        for part in ("owner", "repo"):
            if not isinstance(source.get(part), str) or not SOURCE_PART.fullmatch(source[part]) or source[part] in (".", ".."):
                raise ReviewError("Invalid guarded source identity")
    return sources


def evaluate_pull(api, pull, sources):
    base = api.lock(pull["base"]["sha"])
    head = api.lock(pull["head"]["sha"])
    reviews = []
    permissions = {}
    author = pull["user"]["login"].lower()
    for review in api.pages(f"pulls/{pull['number']}/reviews"):
        user = review.get("user")
        if not isinstance(user, dict) or user.get("type") != "User":
            continue
        login = user.get("login")
        if not isinstance(login, str) or not login or login.lower() == author:
            continue
        reviews.append(review)
        if login not in permissions:
            permission = object_value(api.request(api.path("collaborators/" + quote(login, safe="") + "/permission")), "collaborator permission")
            role = permission.get("permission")
            if not isinstance(role, str):
                raise ReviewError("Malformed collaborator permission")
            permissions[login] = role
    return evaluate(base, head, reviews, permissions, sources, pull["head"]["sha"])


def same_snapshot(first, second):
    return (first["head"]["sha"], first["base"]["sha"], first["state"]) == (second["head"]["sha"], second["base"]["sha"], second["state"])


def write_output(approved):
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        raise ReviewError("GITHUB_OUTPUT is required for gate")
    with open(output, "a", encoding="utf-8") as stream:
        stream.write(f"approved={'true' if approved else 'false'}\n")


def gate(api, event, event_name):
    write_output(False)
    if event_name not in ("pull_request", "pull_request_review"):
        raise ReviewError("gate requires a pull_request or pull_request_review event")
    event_pull = event["pull_request"]
    pull = api.pull(number_value(event_pull["number"]))
    if pull["state"] != "open" or pull["base"].get("ref") != "main" or sha_value(event_pull["head"]["sha"]) != sha_value(pull["head"]["sha"]):
        raise ReviewError("Stale, closed, or non-main pull request event; builds are not authorized")
    result = evaluate_pull(api, pull, load_sources())
    if not same_snapshot(pull, api.pull(pull["number"])):
        raise ReviewError("Pull request changed during evaluation; builds are not authorized")
    write_output(result["approved"])
    print("Skill inputs approved for current head." if result["approved"] else "Skill input changes await a human Approve review on the current PR head.")
    print(json.dumps(result, sort_keys=True))


def report_numbers(api, event, event_name):
    if event_name == "pull_request_target":
        return [number_value(event["pull_request"]["number"])]
    if event_name != "workflow_run":
        raise ReviewError("report requires pull_request_target or workflow_run")
    run = object_value(event["workflow_run"], "workflow run")
    if run.get("name") != "CI" or run["repository"]["full_name"].lower() != api.repo.lower():
        raise ReviewError("Unexpected workflow run source")
    run_sha = sha_value(run["head_sha"])
    candidates = run.get("pull_requests")
    if not isinstance(candidates, list):
        raise ReviewError("Malformed workflow pull request list")
    if not candidates:
        candidates = list(api.pages(f"commits/{run_sha}/pulls"))
    numbers = []
    for candidate in candidates:
        number = number_value(candidate["number"])
        pull = api.pull(number)
        if pull["state"] != "open":
            continue
        # Relay only runs actually associated with this live PR. A synthetic merge
        # SHA can be the workflow head, so also accept GitHub's current merge SHA.
        member = run_sha in (pull["head"]["sha"].lower(), str(pull.get("merge_commit_sha", "")).lower())
        if not member:
            member = any(commit.get("sha", "").lower() == run_sha for commit in api.pages(f"pulls/{number}/commits"))
        if member and number not in numbers:
            numbers.append(number)
    return numbers


def git_environment(home):
    # Do not inherit tokens, credential helpers, injected GIT_CONFIG_* settings,
    # object alternates, proxy commands, or user/system Git configuration.
    return {
        "PATH": os.environ.get("PATH", os.defpath),
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home),
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_ALLOW_PROTOCOL": "https",
        "LC_ALL": "C",
    }


def run_git(directory, environment, *arguments, stdout=None):
    command = ["git", "-c", "core.hooksPath=" + os.devnull,
               "-c", "credential.helper=", "-c", "http.followRedirects=false",
               "-c", "protocol.allow=never", "-c", "protocol.https.allow=always",
               "-c", "core.quotePath=true", "-c", "diff.external=",
               "-C", str(directory), *arguments]
    result = subprocess.run(command, env=environment, stdout=subprocess.PIPE if stdout is None else stdout,
                            stderr=subprocess.PIPE, check=False, timeout=300)
    if result.returncode:
        # stderr may contain arbitrary upstream text; do not emit it as Actions commands.
        raise ReviewError(f"Git {arguments[0]} failed (exit {result.returncode})")
    return result.stdout


def upstream_diffs(changes, sources, patch_path=PATCH_PATH):
    with open(patch_path, "ab") as artifact, tempfile.TemporaryDirectory(prefix="skill-input-review-") as temporary:
        home = Path(temporary)
        environment = git_environment(home)
        for index, change in enumerate(changes):
            name = change["name"]
            source = sources[name]
            before, after = change["before"], change["after"]
            # Independently enforce the allowlist before invoking a subprocess.
            for locked in (before, after):
                if locked["owner"] != source["owner"] or locked["repo"] != source["repo"]:
                    raise ReviewError("Diff source is not allowlisted")
                sha_value(locked["rev"])
            directory = home / str(index)
            directory.mkdir()
            run_git(directory, environment, "init", "--bare", "--template=")
            remote = f"https://github.com/{source['owner']}/{source['repo']}.git"
            for revision in dict.fromkeys((before["rev"], after["rev"])):
                run_git(directory, environment, "fetch", "--no-tags", "--no-recurse-submodules", "--depth=1", remote, revision)
                resolved = run_git(directory, environment, "rev-parse", "--verify", revision + "^{commit}").decode("ascii").strip()
                if resolved.lower() != revision.lower():
                    raise ReviewError("Fetched source commit does not match pinned revision")
            # Explicit two-tree comparison, never GitHub's merge-base compare patch.
            diff_args = ("--no-ext-diff", "--no-textconv", "--no-renames", before["rev"] + "^{tree}", after["rev"] + "^{tree}", "--")
            artifact.write(f"\n# {name}: {before['rev']} -> {after['rev']}\n".encode("ascii"))
            artifact.flush()
            run_git(directory, environment, "diff", "--binary", "--full-index", *diff_args, stdout=artifact)


def safe_text(text):
    # Escape markup and neutralize mentions in diagnostic output.
    return html.escape(str(text)).replace("@", "&#64;")


def comment_body(pull, result, run_url):
    if not result["changes"]:
        return None
    head = sha_value(pull["head"]["sha"])[:7]
    if result["approved"]:
        state = f"**Approved** for PR head `{head}`."
    else:
        state = f"Review the diffs, then **Approve** this PR at `{head}` (write access required)."
    rows = ["| Skill input | Upstream diff |", "| --- | --- |"]
    for change in result["changes"]:
        before, after = change["before"], change["after"]
        compare = f"https://github.com/{quote(after['owner'], safe='')}/{quote(after['repo'], safe='')}/compare/{before['rev']}..{after['rev']}"
        rows.append(f"| {safe_text(change['name'])} | [`{before['rev'][:7]}` → `{after['rev'][:7]}`]({compare}) |")
    body = "\n\n".join([MARKER, "## Skill input review", state, "\n".join(rows),
                         f"[Full patch artifact]({run_url}#artifacts) · exact pinned-tree diff."])
    if len(body) > 60000:
        raise ReviewError("Review summary exceeds the safe GitHub comment size")
    return body


def sticky_comment(api, number, body):
    matches = []
    for comment in api.pages(f"issues/{number}/comments"):
        user = comment.get("user") or {}
        if user.get("login") == "github-actions[bot]" and user.get("type") == "Bot" and isinstance(comment.get("body"), str) and comment["body"].startswith(MARKER):
            matches.append(comment)
    if body is None:
        for comment in matches:
            api.request(api.path(f"issues/comments/{number_value(comment['id'])}"), "DELETE")
    elif matches:
        first = matches[0]
        api.request(api.path(f"issues/comments/{number_value(first['id'])}"), "PATCH", {"body": body})
        for duplicate in matches[1:]:
            api.request(api.path(f"issues/comments/{number_value(duplicate['id'])}"), "DELETE")
    else:
        api.request(api.path(f"issues/{number}/comments"), "POST", {"body": body})


def publish_status(api, number, expected, state, description, run_url):
    current = api.pull(number)
    if not same_snapshot(expected, current) or current["state"] != "open":
        raise ReviewError("Pull request changed before status publication")
    api.request(api.path(f"statuses/{sha_value(current['head']['sha'])}"), "POST", {
        "state": state, "context": STATUS_CONTEXT,
        "description": description, "target_url": run_url,
    })


def invalidate_status(api, number, known, run_url):
    # Re-read the live head, including after an evaluation/network failure. If that
    # request itself fails, revoke any previous success on the last known head.
    try:
        current = api.pull(number)
        if current["state"] != "open":
            return
        known = current
    except Exception:
        if known is None:
            raise
    api.request(api.path(f"statuses/{sha_value(known['head']['sha'])}"), "POST", {
        "state": "error", "context": STATUS_CONTEXT,
        "description": "Skill input review failed closed; inspect the controller run.",
        "target_url": run_url,
    })


def report_pull(api, number, sources, run_url, patch_path):
    pull = None
    try:
        pull = api.pull(number)
        if pull["state"] != "open":
            return
        if pull["base"].get("ref") != "main":
            raise ReviewError("Skill review only authorizes pull requests targeting main")
        # Clear earlier success before any fallible policy/diff processing.
        publish_status(api, number, pull, "pending", "Evaluating current skill input review.", run_url)
        if sources is None:
            sources = load_sources()
        result = evaluate_pull(api, pull, sources)
        if result["changes"]:
            upstream_diffs(result["changes"], sources, patch_path)
        current = api.pull(number)
        if not same_snapshot(pull, current):
            raise ReviewError("Pull request changed while generating source diffs")
        # Reviews/permissions can change during a slow source fetch. Recompute
        # from live data immediately before publishing the final status.
        result = evaluate_pull(api, current, sources)
        body = comment_body(current, result, run_url)
        sticky_comment(api, number, body)
        publish_status(api, number, current, "success" if result["approved"] else "pending",
                       "Skill input contents approved." if result["approved"] else "Waiting for human approval of current skill input changes.", run_url)
        print(f"PR #{number}: {'approved' if result['approved'] else 'awaiting human approval'}")
    except Exception:
        try:
            invalidate_status(api, number, pull, run_url)
        except Exception as error:
            print(f"Unable to publish fail-closed status: {safe_text(error)}", file=sys.stderr)
        raise


def invalidate_routing_failure(api, event, event_name, run_url):
    """Revoke known heads even when resolving a relay's PR list fails."""
    if event_name == "pull_request_target":
        candidates = [event.get("pull_request", {})]
    elif event_name == "workflow_run":
        run = object_value(event.get("workflow_run"), "workflow run")
        if run.get("name") != "CI" or run.get("repository", {}).get("full_name", "").lower() != api.repo.lower():
            return
        candidates = run.get("pull_requests") or []
    else:
        return
    for candidate in candidates:
        try:
            number = number_value(candidate["number"])
            known = candidate if isinstance(candidate.get("head"), dict) and SHA.fullmatch(str(candidate["head"].get("sha", ""))) else None
            invalidate_status(api, number, known, run_url)
        except Exception as error:
            print("Unable to invalidate routed PR: " + safe_text(error), file=sys.stderr)
    if not candidates and event_name == "workflow_run":
        # An association lookup can fail before any PR number is known. Its
        # known run SHA can only be demoted, never authorized, in that case.
        run_sha = sha_value(event["workflow_run"]["head_sha"])
        api.request(api.path(f"statuses/{run_sha}"), "POST", {
            "state": "error", "context": STATUS_CONTEXT,
            "description": "Unable to resolve skill input review pull request.",
            "target_url": run_url,
        })


def route(api, event, event_name, run_id):
    if not run_id.isdecimal():
        raise ReviewError("GITHUB_RUN_ID must be numeric")
    run_url = f"{api.server}/{api.repo}/actions/runs/{run_id}"
    try:
        return run_url, report_numbers(api, event, event_name)
    except Exception:
        try:
            invalidate_routing_failure(api, event, event_name, run_url)
        except Exception as error:
            print("Unable to invalidate failed event routing: " + safe_text(error), file=sys.stderr)
        raise


def report(api, event, event_name, run_id, selected=None):
    run_url, numbers = route(api, event, event_name, run_id)
    if selected is not None:
        # Matrix values identify PRs, never an approval decision.
        numbers = [number_value(selected)] if selected in numbers else []
    try:
        PATCH_PATH.write_bytes(b"")
    except OSError:
        for number in numbers:
            invalidate_status(api, number, None, run_url)
        raise
    errors = []
    for number in numbers:
        try:
            report_pull(api, number, None, run_url, PATCH_PATH)
        except Exception as error:
            try:
                # The initial live PR read may itself have failed; retain the
                # event's known SHA only as an error-status fallback.
                invalidate_routing_failure(api, event, event_name, run_url)
            except Exception as status_error:
                print("Unable to invalidate failed report: " + safe_text(status_error), file=sys.stderr)
            errors.append(error)
    if errors:
        raise ReviewError("; ".join(str(error) for error in errors))
    if not numbers:
        print("No open associated pull requests; nothing to report.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("gate", "route", "report"))
    parser.add_argument("--pull", type=int, help="Report only this routed PR")
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "gate":
            write_output(False)
        api = GitHub(os.environ["GH_REPO"], os.environ["GH_TOKEN"], os.environ.get("GITHUB_SERVER_URL", "https://github.com"))
        event = read_json(os.environ["GITHUB_EVENT_PATH"])
        event_name = os.environ["GITHUB_EVENT_NAME"]
        if arguments.command == "gate":
            gate(api, event, event_name)
        elif arguments.command == "route":
            _, numbers = route(api, event, event_name, os.environ["GITHUB_RUN_ID"])
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
                stream.write("pulls=" + json.dumps(numbers) + "\n")
        else:
            report(api, event, event_name, os.environ["GITHUB_RUN_ID"], arguments.pull)
        return 0
    except Exception as error:
        # Single-line, escaped errors cannot inject GitHub workflow commands.
        print("Skill input review failed: " + safe_text(str(error)).replace("\n", " ").replace("\r", " "), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
