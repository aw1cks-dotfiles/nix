---
name: git-history-hygiene
description: Use when deciding how to integrate a branch (rebase versus merge commit), shaping commits so they survive review and repeated rebases, or cutting merge-conflict churn across concurrent branches. Covers history shape, conflict cost, force-push review round-trips, and the git config that supports them. Not for branch naming, commit message format, or PR templates; use the git-workflow skill for those.
---

# Git History Hygiene

Assumes a branch shared with other people and git >= 2.38; commands verified on
git 2.54.0.

## Integration model

Linear is the default: rebase onto the default branch, integrate fast-forward.

Use a merge commit instead when:

- the branch is already someone else's base, so rewriting it breaks their work
  (`git branch -r --contains <sha>` finds them);
- it is a long-running integration or release line whose tested combined state
  is the artifact;
- the conflict resolution is the artifact. A merge commit records it once,
  against the final state; a rebase replays it per commit, against intermediate
  states that never existed upstream.

Linear history's advantage (`bisect`, `revert`, `cherry-pick`, `blame`) holds
only while every commit is shippable. Otherwise it is worse than the merge
history it replaced: `bisect` lands on broken commits and there is no merge
commit to skip.

## Make every commit shippable

- Replay with checks rather than hoping: `git rebase -i @{u} --exec '<test command>'`.
  Add `--exec 'git diff --check'` to catch whitespace churn.
- Test the commit, not the worktree plus the commit: `git stash push --keep-index`,
  run the checks, `git stash pop`.
- Land review fixes as fixups: `git commit --fixup=<sha>`, then
  `git rebase -i --autosquash`. With `rebase.autoSquash=true`, plain `git rebase -i`
  does it.
- Before pushing a rewritten branch, confirm it still merges:
  `git merge-tree --write-tree <default-branch> HEAD`. Prints a tree oid and exits 0;
  prints `CONFLICT` lines and exits 1 otherwise. No worktree churn.

## Conflict cost

Conflicts scale with overlapping file *regions* between branches, not with commit
size or count.

- Renames get their own commit, before any content change in the same file.
  Whole-file rename detection then keeps `git log --follow` working.
- Hot files — registries, append-only lists, `mod.rs` / `__init__.py` re-exports,
  lockfiles — get their own commit so they can be dropped or replayed independently.
- Split by reason, not by file, when one file has two reasons; split by file when
  the reasons overlap the same region.
- Formatter runs and mass reformats are their own commit, registered in
  `.git-blame-ignore-revs`.
- `.gitattributes` with `* text=auto eol=lf`. A line-ending flip conflicts every line.

## Force-push round-trips

- After rewriting a pushed branch, give reviewers the delta rather than the new
  history: `git range-diff <base> <old-tip> <new-tip>`. Take the old tip from the
  reflog (`HEAD@{1}`) or record it in the PR thread; reflog expiry loses it.
- Push rewritten branches with `git push --force-with-lease --force-if-includes`,
  never bare `--force`.

## Config

`modules/home/vcs/default.nix` sets the baseline described in this skill on every
managed host:

- `rerere.enable`, `rerere.autoupdate` — recorded resolutions replay and re-stage
  across rebases.
- `rebase.autoSquash`, `rebase.updateRefs` — fixups fold in on a plain
  `git rebase -i`, and stacked branches follow the rebase.
- `merge.conflictStyle=zdiff3`, `diff.algorithm=histogram` — conflict context, and
  fewer spurious conflicts on moved blocks.
- `commit.verbose`, `branch.sort=-committerdate`, `pull.rebase=merges`,
  `push.default=simple`, `push.autoSetupRemote=true`, `fetch.prune=true`,
  `log.follow=true`, `diff.renames=true`.

`blame.ignoreRevsFile` is deliberately not global: a configured path that does not
exist makes `git blame` fail with `fatal: could not open object name list`, so each
repository opts in with `git config --local blame.ignoreRevsFile .git-blame-ignore-revs`.

On an unmanaged host, the same effect comes from `git config --global rerere.enabled true`,
`rerere.autoupdate true`, `rebase.autoSquash true`, `rebase.updateRefs true`,
`diff.algorithm histogram`, `commit.verbose true`, `branch.sort -committerdate`.
