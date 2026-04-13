---
name: host-facts
description: Use this skill when adding hosts, changing host metadata, or updating constructor-owned role defaults.
---

# Host Facts

Use this skill when adding a host, changing host metadata, or updating constructor-owned role defaults.

## Contract

- Shared host metadata lives in `hosts/_facts.nix` as plain data and is exposed through `hosts/facts.nix`.
- Constructors inject `hostFacts` with `specialArgs` for NixOS and darwin, and `extraSpecialArgs` for standalone Home Manager.
- Constructors also expand role-derived imports automatically from `hostFacts.roles`.
- Constructors should consume shared facts centrally when they can, instead of making host roots repeat values that already exist in facts.
- Host files remain explicit composition roots for host-local wiring and local overrides.

## Facts Schema

Required fields per host:

```nix
{
  system = "...";
  kind = "nixos" | "darwin" | "home-manager";
  roles = [ ... ];
}
```

Optional shared fields:

```nix
{
  user = "...";
  homeDirectory = "...";
  hostName = "...";
  tags = [ ... ];
}
```

## Boundary Rules

Facts:

- safe, normalized metadata intended to be shared across module layers
- system, kind, roles, usernames, home directories, public hostnames, tags

Composition:

- host-local `module` payloads
- embedded `home` payloads
- local file paths
- NVIDIA pin file paths such as `hosts/<host>/nvidia.json`
- constructor-only wiring

Secrets:

- passwords, tokens, private endpoints, private keys
- any agenix-managed value
- anything exposed via `age.secrets.*`

Never put composition-only values or secrets in `hosts/_facts.nix`.

## Role Defaults

- Central mapping lives in `modules/roles/defaults.nix` as `config.aw1cks.roles`.
- Reuse existing profile bundles rather than replacing the profile model.
- Do not restate the live role inventory in docs or reviews unless the exact mapping is the point of the change. Treat `modules/roles/defaults.nix` and `docs/adding-a-role.md` as authoritative.

## Override Semantics

- Constructors expand role-derived imports before host-local modules.
- Constructors also apply shared facts like `user`, `homeDirectory`, and darwin `nixpkgs.hostPlatform` with defaults where appropriate.
- Host-local modules and embedded homes come later and override through normal module ordering.
- Prefer `mkDefault` and additive merges inside reusable defaults when host variance is likely.

## Host Workflow

1. Add a normalized facts entry in `hosts/_facts.nix`.
2. Add the repo-local host composition root under `hosts/<name>/configuration.nix`.
3. Keep local paths, embedded home payloads, and NVIDIA pin wiring in the host file, but avoid repeating values that constructors already derive from facts.
4. If the host needs secrets, add agenix wiring separately; do not place secret data in facts.
5. Validate the narrowest constructor or flake path affected by the change.
