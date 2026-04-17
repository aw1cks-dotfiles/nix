---
name: agent-routing-policy
description: Select the right agent lane, escalate deliberately, and avoid ad hoc reasoning overrides.
---

## What I do

I am the source of truth for OpenCode lane selection, escalation, and reasoning discipline.

Treat agent selection as the primary control for cost, speed, and reasoning quality.
Do not try to compensate for the wrong agent choice with longer prompts or ad hoc requests to think harder.

## Lane Classification

Before substantial work, classify the task into one of these lanes:

- discovery
- compression
- implementation
- utility
- review
- premium judgment

## Agent Mapping

- `explore` for file discovery, symbol search, dependency tracing, and read-only narrowing
- `summary-helper` for logs, long command output, long docs, and raw text compression
- `general` for normal implementation and edits after scope is clear
- `fast-helper` for low-risk helper work, quick hypotheses, and cheap utility tasks; treat its output as advisory until verified
- `deep-review` for wide diffs, subtle judgment, repo-level synthesis, and final review on higher-risk changes
- `premium-review` only when mistakes are expensive and extra judgment is likely to pay for itself
- `experimental-open` only for cheap helper work, summaries, or alternative drafts; do not rely on it as the final authority for repo-affecting changes

## Routing Rules

- If the task is ambiguous or mostly about finding the right files, start with `explore`
- If the input is large raw text, start with `summary-helper`
- If the change is straightforward and scoped, use `general`
- If the first implementation attempt fails, escalate from `general` to `deep-review` before another broad attempt
- If the task spans more than 3 files, touches shared contracts, or has unclear tradeoffs, involve `deep-review`
- Use `premium-review` only for high-consequence judgment, not routine coding

## Reasoning Discipline

- Reasoning settings are owned by the configured agent and model stack
- Do not override reasoning ad hoc in prompts unless the user explicitly asks
- To increase reasoning quality, escalate to the correct agent instead of staying in a cheaper lane

## Execution Discipline

- Briefly state the chosen lane before substantial work
- Briefly state when escalation happens and why
- If you intentionally skip a recommended lane, explain why
