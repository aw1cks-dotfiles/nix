# AGENTS.md

## Scope

This file applies to the entire public repo.

## Repo Context

- This repo is the public reusable Nix library plus a small set of public live host configs.
- Other flakes may consume this repo as an input, including a separate private corporate repo that layers corporate modules and work hosts on top of the shared library.
- `flake.nix` is generated. Do not edit it directly; regenerate with `nix run .#write-flake` when needed.
- Common workflows are exposed through `just`, especially `just rebuild` and `just update`.
- Repo-supported automation should be exposed through flake `apps` or `packages`. Avoid introducing raw `scripts/*` entrypoints as the primary interface when the command should be reproducible and discoverable through the flake.
- Standalone Home Manager NVIDIA hosts use the shared `configurations.home.<name>.nvidia` contract with host-local JSON pin files such as `hosts/<host>/nvidia.json`.

## Load Skills When Relevant

- `.agents/skills/repo-architecture/SKILL.md`: public module boundaries, profiles vs aspects, export-surface rules, generated flake rules, validation expectations.
- `.agents/skills/host-facts/SKILL.md`: host facts schema, constructor injection, role-default mapping, and facts vs composition vs secrets boundaries.
- `.agents/skills/downstream-consumer-workflow/SKILL.md`: changes that affect private downstream consumers, including temporary local path overrides from the private repo.

## Architecture Rules

- Treat this repo as the shared library layer: reusable modules, profiles, flake schemas, and generic tooling belong here.
- Public hosts may live here, but they are repo-local outputs, not part of the reusable downstream interface consumed by other flakes.
- Keep hosts as explicit composition roots.
- When adding repo-supported tooling, prefer a flake `app` for executable workflows and a flake `package` for reusable build artifacts or wrapped tools.
- Shared host metadata belongs in `hosts/_facts.nix`; `hosts/facts.nix` exposes it as `config.flake.hostFacts`.
- Constructors inject `hostFacts` and expand role-derived imports automatically from `hostFacts.roles`.
- Cross-target constructor helpers live in `modules/_lib/default.nix`; keep them small, contract-focused, and avoid turning them into a second module system.
- Prefer consuming shared facts in constructors instead of repeating the same values in repo-local host declarations.
- Prefer `flake.profiles.*` for repeated intent bundles; keep `flake.modules.*` atomic.
- Add `flake.aspects.*` only for narrow cross-cutting machine traits.
- Do not hand-edit generated outputs when the source of truth is `modules/flake-file.nix`.
- Reusable downstream `flake-file.inputs.*` declarations belong only in `modules/_internal/flake-file-inputs/default.nix`, exported as `flake.flakeModules.downstream-flake-file`.
- Keep runtime consumers of those inputs in visible modules such as `modules/integrations/*`; do not put runtime app/package/module exports in the hidden flake-file contract module.

## Host Facts Boundary

- Facts: safe shared metadata such as `system`, `kind`, `roles`, `user`, `homeDirectory`, `hostName`, and tags.
- Composition: host-local `module` wiring, embedded `home` payloads, local file paths, and NVIDIA pin file paths.
- Secrets: any agenix-managed value, `age.secrets.*` material, credentials, tokens, private endpoints, and private keys.
- Never put composition-only values or secrets in `hosts/_facts.nix`.
- Do not repeat values in host roots when constructors already derive them from facts.

## Export Boundary Rules

- Downstream flakes should consume reusable module/profile exports, not repo-local host declarations.
- When changing `flakeModules`, preserve a clear separation between shared exports and this repo's own host outputs.
- Reusable changes should be validated from at least one real downstream consumer when practical.

The key distinction is:
- this repo can be both a reusable library and a live-config repo for its own public hosts
- downstream consumers should only inherit the reusable library surface

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
- Prefer editing files under `modules/` and future `profiles/` trees over generated outputs.
- Temporary agent prompt files belong in `docs/prompts/`. Treat that directory as the standard scratch location for implementation/review prompts that should not be committed.
- If a change affects generated flake output, regenerate `flake.nix` rather than hand-editing it.
- For any new file that must be evaluated by Nix, stage it with git before relying on `nix` commands for validation; untracked files are ignored by flake evaluation, and staged files are the safest default for accurate testing.
- Prefer exposing maintained operational commands via `nix run .#<name>` or `nix build .#<name>` instead of telling users to run repository-local shell scripts directly.
- When changing the downstream flake-file contract, update both `modules/flake-modules.nix` and any explicit imports needed in `modules/flake-file.nix`; `_internal/*` paths are skipped by `import-tree`.
- Prefer introducing or consuming profiles instead of expanding repeated host import lists.
- Prefer mapping `hostFacts.roles` to existing profiles in `modules/roles/defaults.nix` rather than making hosts import repeated role bundles directly.
- When changing constructor assembly, update the docs that describe constructor-owned defaults and helper responsibilities.
- For NVIDIA driver bumps, prefer updating host-local JSON pin files rather than editing host modules in place.

## Verification

- For configuration changes, prefer the narrowest useful validation first.
- Before running validation for changes that add new Nix files or change generated flake inputs, stage the relevant new files first so evaluation sees the intended source tree.
- Use `nix flake check` when it meaningfully covers the change.
- Use `just rebuild` for local apply flows across nix-darwin, NixOS, and standalone Home Manager.
- On macOS bootstrap flows, preserving `NIX_CONFIG` may be required until managed Nix settings are active.
- nix-darwin and standalone Home Manager constructors now inject `hostFacts` and should be the first place to derive shared defaults like user, home directory, and host platform from facts.
- Use `just update` when inputs changed.
- When changing shared exports or configuration contracts, mention whether downstream consumer validation was performed.
- Mention clearly if a change was validated only by static inspection and not by a switch/build.
