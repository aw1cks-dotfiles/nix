# nix

Reusable Nix library plus a small set of public host configurations for NixOS, standalone Home Manager on Linux, and nix-darwin.

This repo is opinionated about a few things:

- shared reusable configuration lives in `modules/`
- repo-local host composition roots live in `hosts/`
- `flake.nix` is generated from `modules/flake-file.nix`
- downstream consumers should reuse exported modules, profiles, and flake-file wiring instead of copying contracts by hand

## Start Here

- Architecture and repo layout: [`docs/architecture.md`](./docs/architecture.md)
- Adding a host: [`docs/adding-a-host.md`](./docs/adding-a-host.md)
- Adding a role: [`docs/adding-a-role.md`](./docs/adding-a-role.md)
- Validation expectations: [`docs/validation.md`](./docs/validation.md)
- Secret-management guidance: [`docs/secret-management.md`](./docs/secret-management.md)
- Downstream template and layering: [`docs/downstream-template.md`](./docs/downstream-template.md)

## Flake Surface

- `flakeModules.default`: reusable module tree plus this repo's host imports
- `flakeModules.downstream-flake-file`: reusable downstream `flake-file.inputs.*` contract from `modules/_internal/flake-file-inputs/default.nix`
- `templates.default`: starter downstream flake layered on top of this library

## Common Commands

- Regenerate the generated flake: `nix run .#write-flake`
- Rebuild the current machine: `just rebuild`
- Run the pinned frontends directly:
  - `nix run .#nh -- ...`
  - `nix run .#home-manager -- ...`
  - `nix run .#darwin -- ...`

## Notes

- Standalone Home Manager hosts use `configurations.home."user@host"` naming.
- The shared NVIDIA contract for standalone Home Manager lives under `configurations.home.<name>.nvidia` and expects a host-local JSON pin file.
- Downstream `flake-file` consumers should import `inputs.dendritic-lib.flakeModules.downstream-flake-file` alongside `inputs.flake-file.flakeModules.default`.
