# AGENTS.md

## Scope

This file applies to the entire public repo.

## Repo Context

- This repo is the public reusable Nix library plus a small set of public live host configs.
- Other flakes may consume this repo as an input, including a separate private corporate repo that layers corporate modules and work hosts on top of the shared library.
- Authoritative human docs live in `docs/architecture.md`, `docs/adding-a-host.md`, `docs/adding-a-role.md`, `docs/validation.md`, `docs/downstream-template.md`, and `docs/secret-management.md`.
- `flake.nix` is generated. Do not edit it directly; regenerate with `nix run .#write-flake` when needed.
- Common workflows are exposed through `just`, especially `just rebuild` and `just update`.
- Repo-supported automation should be exposed through flake `apps` or `packages`. Avoid introducing raw `scripts/*` entrypoints as the primary interface when the command should be reproducible and discoverable through the flake.
- Standalone Home Manager NVIDIA hosts use the shared `configurations.home.<name>.nvidia` contract with host-local JSON pin files such as `hosts/<host>/nvidia.json`.

## Load Skills When Relevant

- Load `.agents/skills/repo-architecture/SKILL.md` for module layout, flake surface, generated flake rules, and validation expectations.
- Load `.agents/skills/host-facts/SKILL.md` for host facts schema, constructor-owned defaults, and facts vs composition vs secrets boundaries.
- Load `.agents/skills/downstream-consumer-workflow/SKILL.md` for reusable-contract changes that affect the downstream private repo.

## Core Rules

- Treat this repo as the shared library layer: reusable modules, profiles, flake schemas, and generic tooling belong here.
- Public hosts may live here, but they are repo-local outputs, not part of the reusable downstream interface consumed by other flakes.
- Keep hosts as explicit composition roots.
- Prefer flake `apps` and `packages` for supported operational tooling.
- Keep reusable schema in `modules/schema/`, constructors in `modules/constructors/`, hidden flake-file contract inputs in `modules/_internal/flake-file-inputs/default.nix`, and runtime consumers in visible modules such as `modules/integrations/*`.
- Prefer `flake.profiles.*` for repeated intent bundles; keep `flake.modules.*` atomic.
- Downstream flakes should consume reusable exports, not repo-local host declarations.

## Nix MCP

This repo should use a local MCP server configured in `opencode.jsonc`:

- server name: `nix`
- command: `uvx mcp-nixos`

Use the Nix MCP first for Nix package, option, flake-input, and cache lookups before falling back to shell commands or web search.

### Use MCP For

- Package discovery and metadata
- Home Manager and nix-darwin option lookup
- Flake input inspection for this repo
- Cache checks before suggesting expensive builds or pin changes
- Nixpkgs version history

### Tool Notes

- `nix_nix(action=search, source=nixos, type=packages, query=...)` for package discovery.
- `nix_nix(action=info, source=nixos, query=...)` for package metadata.
- `nix_nix(action=options, source=home-manager|darwin, query=...)` for option lookup.
- `nix_nix(action=flake-inputs, type=list)` to inspect current flake inputs.
- `nix_nix(action=flake-inputs, type=read, query="<input>:<path>")` to inspect files inside an input.
- `nix_nix(action=cache, query=<pkg>, system=x86_64-linux)` before recommending expensive builds or pin changes.
- `nix_nix_versions(package=...)` for version history.

### Constraints

- `options` does not support `source: nixos`; use `home-manager`, `darwin`, `nixvim`, or `noogle` instead.
- `flake-inputs` with `type: read` requires `query` in `input:path` format, for example `nixpkgs:flake.nix`.
- `cache` requires a package name in `query`.

## Editing Guidance

- Make the smallest correct change.
- Prefer editing files under `modules/`, `hosts/`, and `docs/` rather than generated outputs.
- Temporary agent prompt files belong in `docs/prompts/`. Treat that directory as the standard scratch location for implementation/review prompts that should not be committed.
- If a change affects generated flake output, update `modules/flake-file.nix` first and regenerate with `nix run .#write-flake`.
- For bootstrap-only refactors where the generated flake cannot evaluate far enough to regenerate itself, a minimal temporary bridge edit to `flake.nix` is acceptable only until regeneration succeeds.
- For any new file that must be evaluated by Nix, stage it with git before relying on `nix` commands for validation; untracked files are ignored by flake evaluation, and staged files are the safest default for accurate testing.
- Prefer exposing maintained operational commands via `nix run .#<name>` or `nix build .#<name>` instead of telling users to run repository-local shell scripts directly.
- When changing host facts, constructors, or reusable downstream contracts, rely on the matching skill doc for the detailed workflow instead of duplicating that guidance here.

## Verification

- For configuration changes, prefer the narrowest useful validation first.
- Before running validation for changes that add new Nix files or change generated flake inputs, stage the relevant new files first so evaluation sees the intended source tree.
- Use `nix flake check` when it meaningfully covers the change.
- Use `just rebuild` or a narrower target-specific command only when the change affects actual configuration behavior.
- Use `just update` when inputs changed.
- When changing shared exports or configuration contracts, mention whether downstream consumer validation was performed.
- Mention clearly if a change was validated only by static inspection and not by a switch/build.
