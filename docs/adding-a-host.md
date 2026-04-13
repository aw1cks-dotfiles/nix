# Adding A Host

Add hosts in two places:

- `hosts/facts.nix` for shared metadata
- `hosts/<name>/configuration.nix` for repo-local composition

## 1. Add Facts

Create a normalized entry in `hosts/facts.nix` under `aw1cks.hostFacts`.

Example darwin host:

```nix
{ ... }:
{
  aw1cks.hostFacts.my-host = {
    system = "aarch64-darwin";
    kind = "darwin";
    roles = [ "<role>" ];
    identity = "personal";
    hostName = "my-host";
  };
}
```

Example standalone Home Manager host:

```nix
{ ... }:
{
  aw1cks.hostFacts."alex@laptop" = {
    system = "x86_64-linux";
    kind = "home-manager";
    roles = [ "<role>" ];
    identity = "personal";
  };
}
```

For standalone Home Manager hosts, the facts key must match the configuration name and follow `user@host` or `user@host.domain`.

Keep these out of facts:

- `module`
- embedded `home`
- local paths
- `nvidia.pinFile`
- secrets

## 2. Add The Composition Root

Create `hosts/<name>/configuration.nix` and declare the appropriate `configurations.*` entry.

Example darwin host:

```nix
{ ... }:
{
  configurations.darwin.my-host = {
    module.system.stateVersion = 6;
    home.home.stateVersion = "25.11";
  };
}
```

Example standalone Home Manager host:

```nix
{ ... }:
{
  configurations.home."alex@laptop" = {
    module.home.stateVersion = "25.11";
  };
}
```

Example NixOS host with embedded Home Manager:

```nix
{ ... }:
{
  configurations.nixos.workstation = {
    module.system.stateVersion = "25.11";
    home.home.stateVersion = "25.11";
  };
}
```

Keep host declarations minimal.

Constructors already resolve shared values such as:

- system
- username
- home directory
- darwin hostname and host platform defaults
- role-derived profile imports

The current resolution rules come from `modules/constructors/*.nix`, `modules/constructors/_lib.nix`, and `modules/schema/identity.nix`.

## 3. Keep Local Concerns Local

These belong in the host composition root instead of facts:

- local file paths
- embedded `home` payloads
- NVIDIA enablement and `nvidia.pinFile`
- host-specific module imports
- other constructor-specific toggles

Do not manually re-import role-derived profiles in host files unless you intentionally want extra imports beyond the constructor-owned defaults.

## 4. Standalone Home Manager NVIDIA Hosts

Standalone Linux Home Manager hosts can opt into the shared NVIDIA contract:

```nix
{ ... }:
{
  configurations.home."alex@desktop" = {
    nvidia = {
      enable = true;
      pinFile = ./nvidia.json;
    };
    module.home.stateVersion = "25.11";
  };
}
```

The pin file is JSON and must contain `version` and `sha256` keys.

## 5. Add Secrets Separately

If the host needs secrets:

- wire them through agenix
- add `age.secrets.*` declarations in the relevant module layer
- keep encrypted files and secret values out of `hosts/facts.nix`

See [`docs/secret-management.md`](./secret-management.md).

## 6. Domain-Joined Linux Notes

This mostly matters for standalone Home Manager hosts on non-NixOS Linux.

On some domain-joined machines, Nix-built binaries can fail user, group, or host lookups even though the host itself is configured correctly. A common cause is that the host relies on `sssd` NSS plugins from `/etc/nsswitch.conf`, while non-NixOS Nix-built glibc binaries often cannot use those host NSS plugins directly.

Installing `nscd` with the host package manager can work around that by exposing an `nscd`-compatible socket at `/var/run/nscd/socket`, which glibc will consult for those lookups.

Treat this as an operational workaround, not a repo contract:

- it can be a practical fix when standalone Home Manager bootstrap or runtime behavior depends on NSS lookups
- upstream SSSD guidance warns about running `nscd` alongside `sssd` because of caching and behavior conflicts
- alternatives such as `nsncd` may be a better fit, but they are not yet documented here as a validated standard path

If a downstream environment needs a stronger recommendation than this note, document the validated local approach there rather than promoting an unverified repo-wide rule.

## 7. Validate Narrowly

Before relying on flake evaluation, ensure any new Nix files are tracked by git.

Then run the narrowest useful validation for the affected constructor path.

Use `nix flake check` when it meaningfully covers the change, but do not treat it as a full deployment test. See [`docs/validation.md`](./validation.md).
