# Adding A Role

Roles are shared intent labels declared in `hosts/facts.nix`.

In this repo, roles are constructor-owned metadata, not a second module tree. Constructors expand them through the central mapping in `modules/roles/defaults.nix`.

## 1. Decide Whether It Is Really A Role

Add a role when the label describes repeated host intent that should apply automatically across multiple hosts.

Use other layers when the need is narrower:

- use `aw1cks.modules.<target>.*` for atomic reusable features
- use `aw1cks.profiles.<target>.*` for repeated bundles
- use host-local wiring for one-off machine details

## 2. Reuse Profiles First

Prefer mapping a new role to existing profiles. If the reusable bundle does not exist yet, add or refine a profile first.

The stable pattern is:

- roles are declared in `hostFacts.roles`
- `modules/roles/defaults.nix` maps those role names onto target-specific profiles
- constructors import the mapped profiles before host-local modules

Avoid documenting the live role inventory in prose. Treat `modules/roles/defaults.nix` as the authoritative mapping.

## 3. Update `modules/roles/defaults.nix`

Add the mapping in the target layer where it belongs:

- `config.aw1cks.roles.home`
- `config.aw1cks.roles.darwin`
- `config.aw1cks.roles.nixos`

Hosts only need the new role label in `hosts/facts.nix` once the mapping exists.

## 4. Preserve Override Semantics

Role defaults must stay overridable.

- import role-derived defaults before host-local payloads
- prefer plain assignments, `mkDefault`, and additive merges
- avoid `mkForce` unless the behavior must be mandatory

Unknown roles are treated as constructor assertion failures.

## 5. Update Facts Entries

After adding the mapping, add the new role string to the relevant hosts in `hosts/facts.nix`.

## 6. Document And Validate

If the new role changes the reusable contract, update the relevant docs and mention whether downstream validation was performed.

Validate the narrowest useful path first, then run broader checks if the role changes shared constructor behavior.
