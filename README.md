# nix

Reusable Nix library plus public live host configurations for NixOS, standalone Home Manager, and nix-darwin.

## Platforms

- NixOS
- Generic Linux (home-manager)
- macOS (nix-darwin)

## Patterns used in this repository

- [flake-parts](https://flake.parts) is used throughout
- The [dendritic pattern](https://github.com/mightyiam/dendritic) is followed; each Nix file is a standalone flake-parts module
- The main [`flake.nix`](./flake.nix) is generated using [flake-file](http://github.com/vic/flake-file)
- Downstream `flake-file` consumers can import `inputs.dendritic-lib.flakeModules.downstream-flake-file` alongside `inputs.flake-file.flakeModules.default` to share the library's reusable flake input contract
- [import-tree](https://github.com/vic/import-tree) is used within the [modules](./modules/flake-modules.nix)
    - All Nix files in the path are recursively imported, except for any path beginning with `_`, e.g. [`_lib`](./modules/_lib)
    - [Hosts](./modules/hosts/) themselves are also modules. These import other modules, which are groups of configuration the host opts into.
    - All modules are outputs of the flake, so that they can be consumed from other flakes.
- Secrets are managed with [agenix](https://github.com/ryantm/agenix)
- TODO: Adopt [den](https://github.com/vic/den) to create aspect-based groupings of modules

## Downstream Flake-File Contract

Reusable public `flake-file.inputs.*` declarations live in `modules/_internal/flake-file-inputs/default.nix`.
That hidden module is exported as `flakeModules.downstream-flake-file` and is imported explicitly by this repo's own flake generation and reusable module surface.

Downstream consumers should use `flakeModules.downstream-flake-file` as the source of truth for the reusable transitive input contract and wire it into their `flake-file` source alongside the base `flake-file` module.

That keeps the public library's reusable transitive inputs in one place and avoids duplicating the contract in downstream repos.

Runtime integrations that consume those inputs live under `modules/integrations/`.

## Deploying

### Prerequisites

For darwin and standalone Home Manager hosts, install a multi-user Nix daemon
manually to bootstrap the configuration. The recommended happy path is
[Lix](https://lix.systems/), which enables the required defaults out of the box.

Our configuration relies on `flakes` and `nix-command`.

`trusted-users` should also cover your user directly or via an admin group,
especially for standalone Home Manager hosts where daemon settings are not
managed declaratively post-bootstrap.

```sh
$ LIX_INSTALLER="$(mktemp)"
$ curl --proto 'https' --tlsv1.2 -fsSLo "$LIX_INSTALLER" https://install.lix.systems/lix
$ less "$LIX_INSTALLER" # inspect the installer to make sure it looks correct
$ sh "$LIX_INSTALLER" install \
    --extra-conf 'trusted-users = root @wheel @sudo'
$ rm -vf "$LIX_INSTALLER"
```

#### Domain-joined machines

If running on a domain-joined Linux machine, apps may have issues with UID,
group, or host lookups. This is usually because `sssd` provides that
functionality through NSS plugins configured in `/etc/nsswitch.conf`, and
Nix-built glibc binaries on non-NixOS systems often cannot use the host NSS
plugins directly.

Installing `nscd` via the host package manager is a known workaround here and
has worked reliably on a few machines. Nix's libc will check for
`/var/run/nscd/socket`, so an `nscd`-compatible daemon can bridge those
lookups without requiring Nix-built binaries to load the host NSS plugins
themselves.

This is still suboptimal: upstream SSSD documentation advises against running
`nscd` alongside `sssd` because of caching and behavior conflicts.

Possible alternatives that are not yet validated:
- Use [nsncd](https://github.com/twosigma/nsncd), an `nscd`-compatible daemon that forwards lookups without glibc `nscd`'s caching behavior
- Make the required NSS modules discoverable to Nix-built binaries directly instead of routing lookups through an `nscd`-compatible socket
  - In practice this likely means a glibc/NSS setup that can expose `libnss_sss` compatibly to those binaries
  - The exact implementation is environment-specific and still untested here

### Rebuilding the current machine

The pinned `nh` CLI is exposed as a flake app on all supported platforms.

Bootstrap rebuilds can be run directly with:

If you are not using Lix, ensure `nix-command` and `flakes` are enabled before
running these commands.

```sh
nix run .#nh -- darwin switch .
nix run .#nh -- os switch .
nix run .#nh -- home switch .
```

Once `just` is available, `just rebuild` wraps the same pinned `nh` entrypoint:

- nix-darwin: `just rebuild`
- NixOS: `just rebuild`
- standalone Home Manager on non-NixOS Linux: `just rebuild`

### Running pinned frontends directly

This flake exposes pinned app entrypoints for the shared frontends:

- `nix run .#nh -- ...`
- `nix run .#darwin -- ...`
- `nix run .#home-manager -- ...`

For example:

```sh
nix run .#nh -- home switch .
nix run .#home-manager -- switch --flake .
```

### Home Manager NVIDIA schema

Standalone Home Manager Linux hosts can opt into the shared NVIDIA contract at the top level of `configurations.home.<name>`:

```nix
{
  system = "x86_64-linux";
  nvidia = {
    enable = true;
    pinFile = ./nvidia.json;
  };
  module = {
    imports = [
      profiles.home.base
      profiles.home.developer
      profiles.home.desktop
    ];

    home = {
      username = "alex";
      homeDirectory = "/home/alex";
      stateVersion = "25.05";
    };
  };
}
```

When `nvidia.enable = true`, the shared Home Manager layer automatically enables `targets.genericLinux` and wires `targets.genericLinux.gpu.nvidia` from the pin file.

Pin files are stored as JSON. NVIDIA-enabled Home Manager hosts must set `nvidia.pinFile` explicitly, typically to a host-local path such as `./nvidia.json`.

The JSON file must contain:

```json
{
  "version": "595.58.03",
  "sha256": "sha256-jA1Plnt5MsSrVxQnKu6BAzkrCnAskq+lVRdtNiBYKfk="
}
```

This metadata is also exposed as `homeNvidiaConfigurations` for updater tooling.

### Updating NVIDIA pins

Use the packaged updater to refresh the version and installer hash for the current machine:

```sh
nix run .#update-nvidia-version
```

For a remote target, pass the version and short hostname explicitly:

```sh
nix run .#update-nvidia-version -- 595.58.03 desktop
```

The updater rewrites the configured JSON pin file directly and no longer edits host Nix modules in place.

### Darwin host schema

Darwin hosts in `configurations.darwin` currently use this top-level shape:

```nix
{
  system = "aarch64-darwin";
  user = "alex";
  homeDirectory = "/Users/alex";
  module = {
    networking.hostName = "mbp";
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
  };
  home = {
    imports = [
      profiles.home.base
      profiles.home.developer
      profiles.home.desktop
    ];

    home.stateVersion = "25.11";
  };
}
```

The shared darwin layer derives `system.primaryUser`, `users.users.<name>.home`, `home-manager.users.<name>.home.username`, and `home-manager.users.<name>.home.homeDirectory` from `user` and `homeDirectory`.

## Constructor Helpers

Cross-target constructor assembly is normalized through small helpers in `modules/_lib/default.nix`.
These helpers are intended to keep repeated constructor policy consistent without hiding the
actual NixOS, nix-darwin, and Home Manager constructor calls.

Current helper responsibilities:

- `hostFactsFor`: resolve a host facts entry and keep error messages consistent
- `roleModulesFor`: expand role-derived profile imports from `config.flake.roles.*`
- `targetAssertions`: emit shared `system` and `kind` assertions
- `constructorArgsFor`: keep `specialArgs` vs `extraSpecialArgs` explicit per target
- `baseModulesFor`: centralize repo-wide baseline imports for `nixos`, `darwin`, `home`, and embedded Home Manager contexts
- `mkHomeUserModule`: shape shared Home Manager user defaults for standalone and embedded use
- `mkPerSystemCheck` and `mergeChecks`: reduce repeated check attrset boilerplate in `modules/checks.nix`
