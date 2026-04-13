# Architecture

This repo is both a reusable public Nix library and a small live-config repo for a few public hosts.

The stable split is:

- reusable schema, constructors, profiles, and integrations live under `modules/`
- repo-local host composition roots live under `hosts/`
- downstream starter material lives under `templates/default/`

## Generated Flake

`flake.nix` is generated.

The source of truth is `modules/flake-file.nix`, which:

- imports `inputs.flake-file.flakeModules.default`
- imports `modules/_internal/flake-file-inputs`
- exports `flakeModules.default`
- exports `flakeModules.downstream-flake-file`
- exposes `templates.default`

The hidden `modules/_internal/flake-file-inputs/default.nix` file is the reusable downstream `flake-file.inputs.*` contract. Runtime consumers of those inputs live in visible modules under `modules/integrations/`.

## Repo Layout

- `modules/schema/`: option schemas for shared namespaces and constructor contracts
- `modules/constructors/`: host constructors for `configurations.nixos`, `configurations.darwin`, and `configurations.home`
- `modules/constructors/_lib.nix`: small shared constructor helpers
- `modules/integrations/`: pinned apps, packages, and flake-input runtime consumers
- `modules/shared/`: cross-target reusable modules
- `modules/home/`, `modules/darwin/`, `modules/nixos/`: target-specific reusable modules and profiles
- `modules/roles/defaults.nix`: role-to-profile mapping used by constructors
- `hosts/facts.nix`: normalized shared host metadata module
- `hosts/<name>/configuration.nix`: repo-local host composition roots

## Shared Namespaces

The public reusable namespace in this repo is `aw1cks.*`.

The important parts are:

- `aw1cks.modules.<target>.*`: atomic reusable modules
- `aw1cks.profiles.<target>.*`: reusable bundles built from those modules
- `aw1cks.hostFacts`: normalized host metadata declared in `hosts/facts.nix`
- `aw1cks.identities`: named identity registry
- `aw1cks.identity.default` and `aw1cks.identity.selected`: default identity selection
- `aw1cks.roles`: constructor-owned role mapping

Downstream repos can keep using `aw1cks.*` as the shared upstream contract while adding their own local namespace for private modules and profiles.

## Identity Model

The current identity model is `aw1cks.identities`, not older `aw1cks.user.*` terminology.

`modules/schema/identity.nix` defines:

- `aw1cks.identities.<name>` entries with `fullName`, `email`, `username`, and optional `homeDirectory`
- `aw1cks.identity.default` as the default selected identity name
- `aw1cks.identity.selected` as the resolved default identity entry

Hosts can also opt into a specific identity with `hostFacts.identity`.

Constructor resolution is:

1. host-local constructor fields when explicitly set
2. matching values from `hostFacts`
3. selected identity values from `aw1cks.identities`
4. a platform-appropriate default home directory when needed

That means shared identity data can provide usernames and home directories without forcing every host root to repeat them.

## Host Facts

`hosts/facts.nix` declares `aw1cks.hostFacts` directly as a module option value.

Required fields per host:

```nix
{
  system = "...";
  kind = "nixos" | "darwin" | "home-manager";
  roles = [ ... ];
}
```

Optional shared metadata includes fields such as:

```nix
{
  identity = "...";
  user = "...";
  homeDirectory = "...";
  hostName = "...";
  tags = [ ... ];
}
```

Facts are for safe shared metadata only.

Keep these out of facts:

- host-local `module` payloads
- embedded `home` payloads
- local file paths
- NVIDIA pin files
- secrets and `age.secrets.*` wiring

## Constructors

The three host constructors are:

- `modules/constructors/nixos.nix`
- `modules/constructors/darwin.nix`
- `modules/constructors/home-manager.nix`

They all:

- resolve a matching facts entry
- assert the configured target kind and system
- inject `hostFacts` via `specialArgs` or `extraSpecialArgs`
- expand role-derived imports from `modules/roles/defaults.nix`
- add shared baseline imports from `modules/constructors/_lib.nix`

The shared helper file `modules/constructors/_lib.nix` is intentionally small. It centralizes repeated constructor policy such as facts lookup, role expansion, target assertions, baseline imports, and user/home resolution.

## Role Expansion

Roles are labels in `hostFacts.roles`.

Constructors do not interpret those labels ad hoc. They consult the central mapping in `modules/roles/defaults.nix`, which maps roles onto reusable profiles per target.

The stable contract is:

- hosts declare roles once in `hosts/facts.nix`
- constructors expand those roles before host-local modules
- host-local modules still override through normal module ordering

The exact current role inventory may change. Treat `modules/roles/defaults.nix` as authoritative for the live mapping.

Unknown role names fail constructor assertions during evaluation.

## Host Configuration Shapes

`configurations.home` is for standalone Home Manager hosts.

- attr names must follow `user@host` or `user@host.domain`
- the `user` segment must match the resolved constructor user
- `nvidia.enable` and `nvidia.pinFile` provide the shared standalone Linux NVIDIA contract

`configurations.nixos` is for NixOS systems.

- hosts can provide an optional embedded `home` payload
- when present, the constructor imports the Home Manager NixOS module through `aw1cks.modules.nixos-home-manager.default`

`configurations.darwin` is for nix-darwin systems.

- hosts can provide an optional embedded `home` payload
- the constructor derives `system.primaryUser`, `users.users.<name>.home`, and Home Manager username/home-directory defaults from resolved identity data

## Validation

Validation is intentionally narrower than a full switch or deployment.

See [`docs/validation.md`](./validation.md) for the current `nix flake check` coverage and its limits.
