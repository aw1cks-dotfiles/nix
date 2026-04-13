---
name: context7
description: Use Context7 MCP tools to fetch up-to-date library and framework documentation. Load whenever writing, planning, or reviewing code that involves any external library, framework, or API.
license: MIT
compatibility: opencode
---

## When to use

Use Context7 before writing or planning any code that involves an external library
or framework. Do not rely on training data for API signatures, method names, or
framework patterns — these go stale. Fetch docs first, then code.

Especially valuable for fast-moving libraries: Next.js, React, Vue, Astro, Tailwind,
any SDK or API client, anything where version matters.

## Tools

Two tools, always used in sequence:

**`resolve-library-id`** — converts a library name to a Context7-compatible ID.

- Input: library name e.g. `"next.js"`, `"supabase"`, `"zod"`
- Returns: a list of candidate IDs e.g. `/vercel/next.js`
- Pick the best match. For ambiguous results, ask the user before proceeding.
- Do not call more than 3 times per task. If unresolved after 3 attempts, use the
  best result available.

**`get-library-docs`** — fetches documentation for a resolved library ID.

- Input: exact ID e.g. `/vercel/next.js`, optional `topic`, optional `page`
- `topic`: narrow the query — be specific. Good: `"jwt middleware"`, `"useEffect cleanup"`. Bad: `"auth"`, `"hooks"`
- `page`: defaults to 1. Paginate (up to 10) if the first result lacks sufficient detail.
- Do not call more than 3 times per task.
- Never include secrets, API keys, or credentials in the query.

## Standard flow

resolve-library-id("next.js")
→ /vercel/next.js
get-library-docs("/vercel/next.js", topic="middleware jwt")
→ current docs injected into context
→ now write the code

## Shortcuts

If the user provides a library ID directly in `/org/project` or
`/org/project/version` format, skip `resolve-library-id` and call
`get-library-docs` immediately.

For a specific version: `/vercel/next.js/v15.0.0`

## Do not

- Write framework-specific code before fetching docs
- Guess at method signatures or import paths from training data
- Call either tool more than 3 times per task
- Use `resolve-library-id` if the user already gave you a `/org/project` ID
