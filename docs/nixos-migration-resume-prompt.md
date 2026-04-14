You are resuming implementation of the NixOS migration work in this repo.

Your job is to pick up the next sensible slice of work from the current repository state and carry it through to a clean handoff point.

## Primary Source Of Truth

Read these first and treat them as authoritative:

- `docs/nixos-migration.md`
- `docs/architecture.md`
- `docs/validation.md`
- `docs/downstream-template.md` when reusable downstream contracts may be affected

Also inspect the relevant repo files for the slice you choose.
Do not assume the migration plan is still hypothetical; reconcile it against the current code before acting.

## Core Objective

Advance the migration by completing the smallest correct end-to-end slice from the checklist in `docs/nixos-migration.md`.

Default priority order:

1. finish the next unchecked item in the current active stream if the dependencies are already satisfied
2. otherwise choose the smallest prerequisite item that unblocks later work
3. prefer shared-foundation work before host-specific polish unless the document clearly indicates a different order

If two checklist items are tightly coupled and cannot land cleanly apart, you may complete them together. Otherwise keep the slice to one item.

## Required Workflow

Follow this loop:

1. inspect the relevant code and docs
2. choose the smallest complete slice
3. implement the change
4. update `docs/nixos-migration.md` in the same change
5. update any other authoritative docs affected by the change
6. run the narrowest useful validation
7. commit the work as an atomic unit

Do not stop after analysis if the next implementation step is clear and safe.
Do not start the next slice after committing unless explicitly asked.

## Subagent Guidance

Use subagents when they reduce context load or separate investigation from implementation cleanly.

Use `explore` for:

- repo reconnaissance
- locating relevant files
- narrow read-only investigation
- gathering concrete evidence about how the current code is wired

Important:

- `explore` is configured with a lower-tier model
- do not delegate architecture decisions, broad synthesis, or reasoning-heavy tradeoff analysis to `explore`

Use `general` for:

- multi-step supporting work that needs stronger reasoning
- comparing implementation options
- synthesizing findings from multiple files or code paths
- larger review-style checks before or after implementation

If the task is straightforward, you may inspect and implement directly without a subagent.

## Repo-Specific Constraints

- keep reusable modules, profiles, schema, and integrations under `modules/`
- keep repo-local host composition roots under `hosts/`
- do not edit generated `flake.nix` directly; update `modules/flake-file.nix` and regenerate if needed
- provisioning outputs should remain repo-local unless a real downstream reusable contract is needed
- do not mechanically port structure from `nixos-experiments`
- preserve the distinction between reusable exports and repo-local host outputs

## Documentation Rules

Documentation must be updated alongside implementation when behavior, architecture, workflows, validation, or reusable contracts change.

At minimum, decide whether the slice requires updates to:

- `docs/nixos-migration.md`
- `docs/architecture.md`
- `docs/validation.md`
- `docs/downstream-template.md`
- `docs/adding-a-host.md`
- `docs/adding-a-role.md`

If no durable doc change is needed beyond the migration tracker, keep that judgment explicit in your reasoning.

## Validation Rules

Use the narrowest useful validation first:

- docs-only changes: static inspection
- schema, constructor, reusable module, or flake-surface changes: `nix flake check` unless a narrower validating path is better
- host-behavior changes: the narrowest host-specific build or evaluation path that exercises the change
- downstream reusable-contract changes: downstream validation when practical

If you add new Nix files that must participate in evaluation, stage them before running Nix-based validation.

## Commit Rules

Commit only when the slice is complete.

Before committing:

- ensure the work is atomic
- ensure the migration doc reflects the new state
- ensure any impacted authoritative docs are updated
- ensure validation has been run, or an explicit validation gap is recorded

Commit message guidance:

- focus on the durable implementation change, not temporary migration scaffolding
- keep the message specific to the completed slice

## Handoff Requirement

Hand off only from a clean, committed state whenever feasible.

Your handoff should leave behind durable artifacts, not just conversational notes:

- updated checklist status in `docs/nixos-migration.md`
- any updated authoritative docs
- one atomic commit

In your final response:

1. state the slice you completed
2. list the files changed
3. state what you validated
4. state any remaining risks or gaps
5. name the next logical checklist item

If blocked, do not force progress. Explain the blocker precisely and identify the smallest decision or missing input needed to continue.
