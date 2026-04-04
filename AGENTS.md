# AGENTS.md

## Scope

This file applies to the entire public repo.

## Repo Context

- This repo is the public reusable Nix library plus a small set of public live host configs.
- Other flakes may consume this repo as an input, including a separate private corporate repo that layers corporate modules and work hosts on top of the shared library.
- `flake.nix` is generated. Do not edit it directly; regenerate with `nix run .#write-flake` when needed.
- Common workflows are exposed through `just`, especially `just rebuild` and `just update`.

## Load Skills When Relevant

- `.agents/skills/repo-architecture/SKILL.md`: public module boundaries, profiles vs aspects, export-surface rules, generated flake rules, validation expectations.
- `.agents/skills/downstream-consumer-workflow/SKILL.md`: changes that affect private downstream consumers, including temporary local path overrides from the private repo.

## Architecture Rules

- Treat this repo as the shared library layer: reusable modules, profiles, flake schemas, and generic tooling belong here.
- Public hosts may live here, but they are repo-local outputs, not part of the reusable downstream interface consumed by other flakes.
- Keep hosts as explicit composition roots.
- Prefer `flake.profiles.*` for repeated intent bundles; keep `flake.modules.*` atomic.
- Add `flake.aspects.*` only for narrow cross-cutting machine traits.
- Do not hand-edit generated outputs when the source of truth is `modules/flake-file.nix` or `outputs.nix`.

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
- If a change affects generated flake output, regenerate `flake.nix` rather than hand-editing it.
- Prefer introducing or consuming profiles instead of expanding repeated host import lists.

## Verification

- For configuration changes, prefer the narrowest useful validation first.
- Use `nix flake check` when it meaningfully covers the change.
- Use `just rebuild` for local apply flows across nix-darwin, NixOS, and standalone Home Manager.
- On macOS bootstrap flows, preserving `NIX_CONFIG` may be required until managed Nix settings are active.
- nix-darwin hosts in this repo currently declare top-level `user` and `homeDirectory`; the shared darwin layer derives the embedded Home Manager username/home directory from those values.
- Use `just update` when inputs changed.
- When changing shared exports or configuration contracts, mention whether downstream consumer validation was performed.
- Mention clearly if a change was validated only by static inspection and not by a switch/build.
