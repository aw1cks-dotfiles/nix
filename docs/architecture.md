# Architecture

This repo is both a reusable public Nix library and a small live-config repo for a few public hosts. Reusable composition stays centered on `flake.modules.*` and `flake.profiles.*`, while repo-local hosts remain explicit composition roots.

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

- NixOS uses `specialArgs = { hostFacts = ...; }`
- nix-darwin uses `specialArgs = { hostFacts = ...; }`
- standalone Home Manager uses `extraSpecialArgs = { hostFacts = ...; }`

That constructor assembly is now normalized through small shared helpers in
`modules/_lib/default.nix`:

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
