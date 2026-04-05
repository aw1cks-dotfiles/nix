# Global Agent Rules

## Git Workflow

When making code changes ALWAYS follow this process:

1. ALWAYS ensure current git status is clean -
   DO NOT continue until the user has committed.

2. Create a new branch before editing:
   `git checkout -b <short-task-name>`

3. NEVER commit directly to `main` or `master`.

4. ALWAYS use concise conventional commit messages.
   Include context in the commit body.

5. ALWAYS create atomic commits - do this as each unit of work is completed.
   DO NOT bundle many changes into a single commit.

6. ALWAYS create clean git history, rebasing where needed.
   For example, if a fix is made to a subsequent commit,
   squash instead of making a new commit, unless there is useful context.

7. After finishing changes, ALWAYS:
   - Run tests / linters / etc.
   - Ensure code builds

## Mandatory Rules

These rules must always be followed:

- NEVER make changes unless the current branch is committed.
- ALWAYS create a git branch before editing code.
- NEVER modify protected branches.
- ALWAYS make sure tests pass before marking tasks as complete.
- ALWAYS use Context7 MCP tools to resolve library IDs and fetch up-to-date docs
  when working with any third-party library or API
