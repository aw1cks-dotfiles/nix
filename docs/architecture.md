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
- `hosts/_facts.nix`: normalized shared host metadata
- `hosts/<name>/configuration.nix`: repo-local host composition roots

## Shared Namespaces

The public reusable namespace in this repo is `aw1cks.*`.

The important parts are:

- `aw1cks.modules.<target>.*`: atomic reusable modules
- `aw1cks.profiles.<target>.*`: reusable bundles built from those modules
- `aw1cks.hostFacts`: normalized host metadata imported from `hosts/_facts.nix`
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

Shared host metadata lives in `hosts/_facts.nix` as plain Nix data. `hosts/facts.nix` exposes that data as `config.flake.hostFacts`. Facts are normalized values intentionally shared across constructor and module layers.

Each host entry must define:

```nix
{
  system = "...";
  kind = "nixos" | "darwin" | "home-manager";
  roles = [ ... ];
}
```

Optional shared fields currently used in this repo are:

```nix
{
  user = "...";
  homeDirectory = "...";
  hostName = "...";
  tags = [ ... ];
}
```

`hosts/_facts.nix` must stay pure data only. Do not use the module system, `lib`, or `pkgs` there.

## Facts Boundary

Facts are for safe shared metadata:

- system architecture
- host kind
- roles
- stable usernames
- home directories
- public hostnames
- tags

Composition parameters stay local to constructors or host files:

- `module`
- embedded `home`
- local file paths
- NVIDIA pin files such as `hosts/<host>/nvidia.json`
- constructor-owned wiring

Secrets stay out of facts entirely:

- passwords
- tokens
- private keys
- private endpoints
- anything managed by agenix
- anything exposed via `age.secrets.*`

## Constructor Injection

Constructors read `config.flake.hostFacts`, assert that a host entry exists, and inject that host's facts as `hostFacts`.

- resolve a matching facts entry
- assert the configured target kind and system
- inject `hostFacts` via `specialArgs` or `extraSpecialArgs`
- expand role-derived imports from `modules/roles/defaults.nix`
- add shared baseline imports from `modules/constructors/_lib.nix`

The shared helper file `modules/constructors/_lib.nix` is intentionally small. It centralizes repeated constructor policy such as facts lookup, role expansion, target assertions, baseline imports, user/home resolution, and check attrset assembly.

- `hostFactsFor` resolves the facts entry and keeps missing-host errors consistent
- `roleModulesFor` expands `config.flake.roles.*` mappings from `hostFacts.roles`
- `targetAssertions` emits the shared `system` and `kind` assertions
- `constructorArgsFor` keeps the `specialArgs` vs `extraSpecialArgs` difference explicit
- `baseModulesFor` centralizes repo-wide baseline imports by target class

Constructors also assert that `hostFacts.system` matches the declared system and that `hostFacts.kind` matches the constructor target.

Where a shared field already exists in facts, prefer consuming it in constructors rather than repeating it in host roots. In this repo that includes `user`, `homeDirectory`, and darwin `nixpkgs.hostPlatform` defaults derived from facts.

## Automatic Role Defaults

Automatic role defaults are constructor-owned. Hosts declare roles once in `hosts/_facts.nix`, and constructors expand role-derived profile imports during constructor assembly before host-local payloads.

The central mapping lives in `modules/roles/defaults.nix` as `config.flake.roles` and currently maps roles onto existing profiles:

- Home Manager always includes `profiles.home.base`
- Home Manager `developer` maps to `profiles.home.developer`
- Home Manager `desktop` maps to `profiles.home.desktop`
- Home Manager `interactive` maps to `profiles.home.interactive`
- Home Manager `multimedia` maps to `profiles.home.multimedia`
- Darwin `desktop` maps to `profiles.darwin.desktop`
- NixOS exposes an empty future-ready role mapping for contract consistency

This preserves the current profile model rather than replacing it with a separate role tree.

## Override Behavior

Role defaults behave like defaults because constructors import them before host-local payloads.

- standalone Home Manager ordering: role defaults, then host module, then host-local extras like NVIDIA wiring
- darwin ordering: darwin role defaults, then shared constructor baseline imports, then host system module, then darwin-specific local wiring
- embedded Home Manager in darwin: home role defaults, then embedded host `home`

Because host-local modules come later, they can override role-derived values through normal Nix module semantics.

That same ordering is used for shared facts defaults. Constructors fill in shared values such as usernames and home directories with `mkDefault`, so host-local modules can still override them when a machine needs a nonstandard setup.

## Agenix

This repo uses agenix for secrets management. Secrets are added through normal agenix module wiring in constructors, not through `hosts/_facts.nix`.

When a host needs secrets:

- keep the host facts entry limited to safe shared metadata
- add `age.secrets.*` declarations in host or reusable modules as needed
- keep encrypted material and any private values out of facts and out of `hostFacts`
