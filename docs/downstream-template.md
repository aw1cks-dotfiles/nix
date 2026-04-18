# Downstream Template

This repo ships `templates.default` as a starter downstream flake that layers private configuration on top of the shared `aw1cks.*` interface.

The authoritative template files live under `templates/default/`.

The template is reference material, not a turnkey downstream repo. Several example host facts and host declarations stay commented out until a real downstream consumer fills them in.

## Purpose

Use the template when you want a downstream repo to:

- consume this repo as a reusable library
- keep organization-specific modules and profiles private
- preserve the shared upstream contract instead of copying constructor wiring by hand

## Flake-File Contract

The downstream template's `modules/flake-file.nix` imports:

- `inputs.flake-file.flakeModules.default`
- `inputs.dendritic-lib.flakeModules.downstream-flake-file`

That means the public library's reusable transitive flake inputs come from this repo's exported contract in `modules/_internal/flake-file-inputs/default.nix`.

Downstream repos should treat that exported module as authoritative unless they are intentionally overriding part of the contract.

## Layering Model

The template demonstrates a simple split:

- `aw1cks.*` stays the shared upstream namespace
- a downstream-local namespace such as `org.*` holds private modules, profiles, and options
- `hosts/facts.nix` provides downstream host metadata
- host configuration roots import downstream profiles and local modules as needed

This keeps shared library concerns reusable while giving the downstream repo room for private certificates, private git settings, internal package sources, and site-specific policies.

## Identity Use In The Template

The template extends `aw1cks.identities` with a downstream-specific identity example in `templates/default/modules/org/meta.nix`.

That example now also shows where to place public SSH authorized keys for the shared identity contract used by NixOS hosts.

Hosts can then select that identity through `hostFacts.identity`, or the downstream repo can change `aw1cks.identity.default` if that should become the default everywhere.

## What The Template Includes

- a downstream `flake-file` source in `templates/default/modules/flake-file.nix`
- example host facts in `templates/default/hosts/facts.nix`
- example host declarations in `templates/default/hosts/examples.nix`
- an example private namespace in `templates/default/modules/org/`
- a generated top-level `templates/default/flake.nix`

## What It Does Not Include

The template does not ship a canonical downstream secrets inventory.

It also does not ship a ready-to-evaluate example host by default; consumers are expected to uncomment or replace the example host data before using it as a real flake.

If a downstream repo adds one, keep it separate from facts and composition roots. See [`docs/secret-management.md`](./secret-management.md) for boundary guidance.

## Typical Workflow

1. Start from `templates.default`.
2. Rename the example downstream namespace if needed.
3. Replace the example identities, domains, and certificate paths.
4. Uncomment and adapt the example host facts and host declarations.
5. Regenerate the generated flake with `nix run .#write-flake` after editing the downstream `modules/flake-file.nix`.
