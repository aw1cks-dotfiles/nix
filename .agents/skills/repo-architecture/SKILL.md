---
name: repo-architecture
description: Use this skill when changing module layout, host composition, flake schemas, export surfaces, or validation in the public repo.
---

# Repo Architecture

Use this skill when changing module layout, host composition, flake schemas, export surfaces, or validation in the public repo.

## Architecture Summary

- This repo is both a reusable public Nix library and a small live-config repo for public hosts.
- Other flakes may consume this repo as a library input, including private or site-specific downstream repos.
- Reusable modules and schema live here.
- Public hosts may also live here, but they should not leak through the reusable interface consumed by downstream flakes.
- Hosts remain the final composition roots.

## Required Composition Pattern

- Keep atomic reusable feature modules in `flake.modules.{home,nixos,darwin}`.
- Prefer composed bundles in `flake.profiles.{home,nixos,darwin}` when hosts would otherwise repeat long import lists.
- Add `flake.aspects.*` only for narrow, cross-cutting machine traits such as `generic-linux`, `nvidia`, or `manuals`.
- Keep shared host facts in `hosts/_facts.nix` and keep composition-only values in host files or constructors.
- Keep cross-target constructor helpers in `modules/_lib/default.nix` small and contract-focused; do not let them become a second module system.
- For standalone Home Manager NVIDIA hosts, keep driver pins in host-local JSON files such as `hosts/<host>/nvidia.json`; keep the reusable contract and wiring in `modules/home-manager/configurations.nix`.

## Host Facts Rules

- `hosts/_facts.nix` is plain data only, and `hosts/facts.nix` exposes it to the flake.
- Facts are limited to safe shared metadata such as `system`, `kind`, `roles`, `user`, `homeDirectory`, `hostName`, and tags.
- Constructors inject `hostFacts` and own automatic role expansion.
- Constructors share helper logic for host lookup, role expansion, target assertions, baseline imports, and constructor arg wiring through `modules/_lib/default.nix`.
- Prefer consuming shared facts in constructors instead of repeating the same values in repo-local host declarations.
- Keep `module`, embedded `home`, local paths, NVIDIA pin file paths, and other composition parameters out of facts.
- Keep agenix-managed values and any `age.secrets.*` material out of facts.

## Export Boundary Rules

- Shared reusable features belong in the exported library surface.
- Repo-local hosts belong in this repo's own outputs, not in the reusable module interface consumed downstream.
- When changing `modules/flake-modules.nix`, preserve a distinction between reusable shared exports and repo-local host imports.
- If a public host stays in this repo, keep that intent explicit rather than letting it leak through `flakeModules.default` by accident.
- Keep reusable downstream `flake-file.inputs.*` declarations in `modules/_internal/flake-file-inputs/default.nix` and export that hidden module as `flakeModules.downstream-flake-file`.
- Because `_internal/*` paths are skipped by `import-tree`, import that hidden module explicitly anywhere the contract must exist, rather than relying on tree recursion.

In other words:
- this repo may build its own hosts
- downstream repos should inherit shared features, not those host declarations

## Current Direction

- Favor adding a profile layer before adding an aspect layer.
- Keep `flake.modules.*` atomic and move repeated import bundles into `flake.profiles.*`.
- Map `hostFacts.roles` onto existing profiles centrally in constructor-owned role mappings.
- Improve validation so active Home Manager configurations are included in `flake.checks`.
- Normalize the top-level `system` contract across `configurations.home`, `configurations.nixos`, and `configurations.darwin`.
- For darwin hosts in this repo, preserve the current top-level host contract while allowing host files to consume shared values from `hostFacts`.

## Naming Guidance

- Prefer names that describe behavior, not implementation leftovers.
- Treat existing `packages/*` and `shells/*` modules as feature modules unless they genuinely represent only packages or shells.
- Prefer `modules/integrations/*` for runtime consumers of flake inputs when the file is not itself the source of truth for `flake-file.inputs.*` declarations.
- Keep profile files short: imports plus a brief membership comment.

## Output And Generation Rules

- `flake.nix` is generated. Edit `modules/flake-file.nix`, then regenerate with `nix run .#write-flake`.
- Prefer editing files under `modules/` and `profiles/` over generated outputs.
- Keep the exported surface intentionally small and documented.

## Validation Expectations

- Prefer the narrowest useful validation first.
- Use `nix flake check` when it covers the change.
- For changes to shared exports or contracts, validate from a real downstream consumer when practical.
- If changing checks, make sure Home Manager activation packages are covered rather than only NixOS builds.
- If changing constructor helpers, update the docs that describe constructor-owned defaults and helper responsibilities.
