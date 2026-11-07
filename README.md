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
- First activation and cache recovery (draft): [`docs/cache-bootstrap.md`](./docs/cache-bootstrap.md)
- Secret-management guidance: [`docs/secret-management.md`](./docs/secret-management.md)
- Downstream template and layering: [`docs/downstream-template.md`](./docs/downstream-template.md)
- Opt-in OMP collab over Tailscale: [`setup and operation`](./docs/downstream-template.md#self-hosted-omp-collab-over-tailscale)
- Private Paseo with OMP Plugin: [`phone setup, authentication, and persistence`](./docs/downstream-template.md#private-paseo-with-the-omp-plugin)
- Nix-authoritative private Serve: [`whole-configuration apply and cleanup`](./docs/downstream-template.md#declarative-private-tailscale-serve)
- Declarative macOS client preferences without replacing Tailscale.app: [`scope and setup`](./docs/downstream-template.md#declarative-tailscaleapp-preferences-on-darwin)

## Flake Surface

- `flakeModules.default`: reusable module tree plus this repo's host imports
- `flakeModules.downstream-flake-file`: reusable downstream `flake-file.inputs.*` contract from `modules/_internal/flake-file-inputs/default.nix`
- `templates.default`: starter downstream flake layered on top of this library

## Common Commands

- Regenerate the generated flake: `nix run .#write-flake`
- Rebuild the current machine: `nix run .#rebuild`
- Update inputs, regenerate the root flake, and fetch input sources: `nix run .#update -- [inputs...]` (arguments are forwarded to `nix flake update`)
- Garbage-collect and optimise: `nix run .#clean -- [days]` (default retention: 7 days)
- Garbage-collect only: `nix run .#clean -- --gc-only [days]`
- Optimise only: `nix run .#clean -- --optimise-only`
- Rebuild through the default app: `nix run .` (alias of `.#rebuild`)
- Run the pinned frontends directly:
  - `nix run .#nh -- ...`
  - `nix run .#home-manager -- ...`
  - `nix run .#darwin -- ...`

Update uses an available `gh` login to reduce GitHub API rate limits; a failed
token lookup still runs without injected credentials. It fetches all input
sources, including unused ones, into the local store. Rebuild does not inject a
token into NH or its elevated commands. A cold-store rebuild, or the initial
`nix run` before the app starts, can still hit unauthenticated rate limits.

Update is checkout-local: `nix run .#update -- nixpkgs` upgrades only that input.
Flags are forwarded only to `nix flake update`; `--flake` is rejected before
changes, so run the app in the checkout you want to update. Normal local input
overrides remain available for integration testing, for example
`nix flake check --override-input dendritic-lib path:/path/to/library`.

`just` is optional sugar for these apps. First activation and cache recovery are
different: use the reviewed source checkout's
`python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py` entry point,
which does not need the flake to evaluate or an app to build. See
[cache bootstrap](./docs/cache-bootstrap.md) before the first activation.

## Notes

- Standalone Home Manager hosts use `configurations.home."user@host"` naming.
- The shared NVIDIA contract for standalone Home Manager lives under `configurations.home.<name>.nvidia` and expects a host-local JSON pin file.
- Downstream `flake-file` consumers should import `inputs.dendritic-lib.flakeModules.downstream-flake-file` alongside `inputs.flake-file.flakeModules.default`.
- Zoom is installed through the Homebrew cask on macOS and `pkgs.zoom-us` on Linux. The macOS cask avoids the ad-hoc-signed Nix package invalidating hash-bound screen-recording permissions after upgrades. When migrating, quit Zoom before `nix run .#rebuild`, then launch `/Applications/zoom.us.app` and grant screen-recording access again; remove stale Home Manager Zoom entries from Privacy & Security if necessary.
