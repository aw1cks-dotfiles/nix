---
name: git-workflow
description: Branching strategy, commit message format, PR process, and release workflow. Load when creating branches, writing commit messages, opening PRs, or preparing releases.
license: MIT
compatibility: opencode
---

## Branching

Identify the default branch before doing anything (`git symbolic-ref refs/remotes/origin/HEAD`
or check `git branch -r`). Branch from it.

Naming: `type/short-description` where type is one of:
`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`

Examples: `feat/add-auth`, `fix/null-pointer-login`

If the repo has an existing branch naming convention, follow it instead.

## Commit atomicity

Commit at each completed unit of work. Commits should be atomic and independently
functional where possible — this makes bisects reliable.

## Clean history

Prefer linear history. Check whether the repo uses rebase or merge as its standard
(`git config --get pull.rebase`, or inspect existing merge commits on the default branch).
Follow whatever pattern is already established.

For small follow-up fixes: stage as a `fixup!` commit, then squash via interactive
rebase before the PR is opened. Only use `--amend` for the most recent unpushed commit.

## Commit messages

Check for a `.gitmessage`, `CONTRIBUTING.md`, or `commitlint` config before writing
any commit — follow project conventions if they exist.

Default to Conventional Commits if no project convention is found:
`type(scope): description`

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`

- Subject line under 72 chars, no trailing period
- Body explains WHY, not WHAT
- Breaking changes: append `!` after type, e.g. `feat(api)!: remove v1 endpoints`

## Pull requests

- PR title matches the primary commit message
- Description: what changed, why it changed, how to test it, linked issue
- One logical change per PR — split if scope creeps
- Check for a PR template (`.github/pull_request_template.md`) and use it if present

## Before marking done

- [ ] Linter passes (if configured)
- [ ] Tests pass (if present)
- [ ] Build passes (if applicable)
- [ ] No uncommitted changes
- [ ] Branch is rebased onto latest default branch (or merged, per repo convention)
- [ ] Commit history is clean — no fixup or WIP commits remain
