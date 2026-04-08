# Adding A Role

Roles are shared intent labels declared in `hosts/_facts.nix`. In this repo, roles map onto existing profile bundles through a central constructor-owned mapping in `modules/roles/defaults.nix`.

## 1. Decide Whether It Is Really A Role

Add a role when the label describes repeated host intent that should apply automatically across multiple hosts.

Use other layers when the need is narrower:

- use `flake.modules.*` for atomic reusable features
- use `flake.profiles.*` for repeated bundles
- use host-local wiring for one-off machine details

## 2. Reuse Profiles First

Prefer mapping a new role to existing profiles. If the reusable bundle does not exist yet, add or refine a profile first.

Example home role mapping shape:

```nix
config.flake.roles.home = {
  base = [ profiles.home.base ];
  roles = {
    developer = [ profiles.home.developer ];
    workstation = [ profiles.home.dev-workstation ];
  };
};
```

Keep the profile model intact instead of replacing it with a separate role directory unless a role needs explicit platform-split implementation files.

## 3. Update `modules/roles/defaults.nix`

Add the new role mapping in the platform layer where it belongs:

- `config.flake.roles.home`
- `config.flake.roles.darwin`
- `config.flake.roles.nixos`

Constructors expand these mappings automatically, so hosts only need the new role label in `hosts/_facts.nix`.

## 4. Preserve Override Semantics

Role defaults must stay overridable.

- import role defaults before host-local payloads
- prefer plain assignments, `mkDefault`, and additive merges
- avoid `mkForce` unless the behavior must be mandatory

## 5. Update Facts Entries

After adding the mapping, add the role string to the relevant hosts in `hosts/_facts.nix`.

## 6. Document And Validate

If the new role changes the reusable contract, update architecture docs and mention whether downstream validation was performed.

Validate the narrowest useful path first, then run broader checks if the role changes shared constructor behavior.
