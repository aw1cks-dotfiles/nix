# Cache bootstrap (draft implementation)

This workflow configures caches **before** the first activation. It does not
install Lix. It requires a working multi-user Lix installation, native shell
utilities, administrator access for host changes, and a reviewed local checkout.
No `just`, `nh`, Home Manager, nix-darwin CLI, flake evaluation, or application build
is needed to render the cache policy.

The implementation is a draft. Shell/transaction tests use service doubles;
first NixOS/nix-darwin/HM activation and launchd behaviour still require disposable
host validation. Do not treat the available recipes as a completed cross-platform
certification.

## Select the configuration owner

| Owner argument | Bootstrap | After bootstrap |
| --- | --- | --- |
| `nixos` | Temporary settings around installed `nixos-rebuild` | Declarative system `nix.settings` |
| `darwin` | Temporary settings before realising the pinned `.#darwin` app | Declarative nix-darwin `nix.settings` |
| `standalone-hm` | Explicitly provision daemon config, then activate HM as the current user | Root-owned `/etc/nix/aw1cks-caches.conf`, updated explicitly |

Ownership is not OS detection. An HM configuration on a NixOS/nix-darwin-owned
machine must use that system's declarative cache configuration, not standalone
provisioning. macOS can also have standalone HM.

The initial target is a **local directory plus `#name`**. Run from this checkout;
a downstream local flake can be passed as the target provided it exports the
pinned `darwin` or `home-manager` app as appropriate. Remote installers/builders,
single-user installations, upstream/Determinate Nix, nonstandard config locations,
and custom service environments are outside this draft's automatic handling.

## First activation, with or without just

```sh
just bootstrap nixos '.#desktop'
just bootstrap darwin '.#macbook'
just bootstrap standalone-hm '.#user@host'
```

Exactly the same source-level entry point works without `just`:

```sh
sh modules/integrations/_cache-bootstrap/bootstrap.sh bootstrap nixos '.#desktop'
sh modules/integrations/_cache-bootstrap/bootstrap.sh bootstrap darwin '.#macbook'
sh modules/integrations/_cache-bootstrap/bootstrap.sh bootstrap standalone-hm '.#user@host'
```

Use a real output name; the macOS/HM names above are illustrative. Run standalone
HM bootstrap as the intended user, **not** with `sudo` around the whole command.
The helper requests sudo only for daemon provisioning. System activation uses an
explicit elevated environment; it does not forward arbitrary caller `NIX_CONFIG`
or use `sudo -E`. Ordinary `just` commands no longer replace the caller's config.
Private-input credentials and proxy settings from the user's environment are not
forwarded across sudo. Any required elevated access must already be configured
through approved system/root-owned settings; this helper is not a credential bridge.

Each write/switch displays its intended policy and prompts. For a reviewed,
non-interactive invocation, put `--yes` before the command. No setting expands
`trusted-users` or disables signature checks. Cache coverage is not guaranteed:
missing substitutes can still require local builds, including a kernel build.

On NixOS/nix-darwin, settings reach the outer frontend and its children through
`NIX_CONFIG`, `NIX_USER_CONF_FILES=/dev/null`, and `NIX_REMOTE=daemon`; the Darwin
outer `nix run` also explicitly selects the daemon. The actual pinned frontends'
propagation and first-activation behaviour remain platform-validation gates.
No temporary daemon fragment is installed on these system-owned paths.

After activation, run `check-caches` again without overrides. Declarative system
configuration must now supply the cache policy. A successful build is not itself
proof of ownership transfer or cache hits.

## How standalone daemon provisioning works

The root helper installs a regular `0644` file at
`/etc/nix/aw1cks-caches.conf` and establishes this required include in the active
standalone `/etc/nix/nix.conf`:

```ini
# BEGIN aw1cks cache provisioning
include /etc/nix/aw1cks-caches.conf
# END aw1cks cache provisioning
```

Lix does not automatically discover `conf.d` fragments. The helper refuses
symlinked, writable, declaratively managed, or ambiguously owned files instead
of overwriting them. It validates both the restricted input fragment and the
complete candidate configuration, including relative admin includes. Parser
warnings and disabled signature checking are failures. Unknown includes or
manual edits in the owned block require operator review.

Updates are serialized, staged on the same filesystem, and installed with the
fragment before the include. The main file's metadata and unrelated settings are
preserved. A verified service name is restarted (`nix-daemon.service` on systemd,
`system/org.nixos.nix-daemon` on launchd); a fresh connection is then checked.
Socket activation is handled by starting/restarting the service, rather than
skipping the operation when it was previously inactive. Restarts can interrupt
other builds. Unsupported/custom service configuration stops the operation.

Root-only transaction backups are kept under `/etc/nix/.aw1cks-caches.*` when
files were changed. On an ordinary failure, the old configuration is restored
and restart is retried. **After removing a cache/key, failure does not silently
restore retired trust**: the new policy stays installed, the operation fails, and
an administrator must inspect the reported backups and service state. There is
no promise of crash-atomicity across two files; include ordering and backups make
an interrupted operation recoverable. An abandoned `.aw1cks-caches.lock` must be
inspected before manual removal.

HM never owns this daemon fragment and never runs sudo as an activation hook.
The existing HM client settings/package selection are preserved for compatibility;
they are not a replacement for daemon trust. This change does not reinstall the
system Lix daemon merely because HM selects `pkgs.lix` for the client.

## Synchronization and recovery

After a cache URL or signing-key change, standalone hosts need an explicit sync:

```sh
just sync-caches
# Without just:
sh modules/integrations/_cache-bootstrap/bootstrap.sh sync-caches
```

The same helper replaces the owned fragment rather than appending entries. A key
removed from that fragment but still present in another loaded daemon file causes
a conflict instead of a false claim that trust was revoked. Replacing a key does
not purge or revalidate objects already in the store. Review root/user overrides
and other configuration owners as part of security-sensitive rotations.

For system bootstrap blocked by an inherited dead cache:

```sh
just recover nixos '.#desktop'
# Without just:
sh modules/integrations/_cache-bootstrap/bootstrap.sh --recovery bootstrap nixos '.#desktop'
```

This deliberately replaces `substituters` and `trusted-public-keys` with the
official cache URL and its key, rejects flake-supplied configuration, and avoids
caller/root user configuration. It does **not** use an empty `extra-*` assignment
as a reset: extra settings append, including when the addition is empty.
Official-only recovery can increase local builds. For standalone HM, the
no-realisation sync repairs the owned fragment first; unrelated admin-owned stale
entries require explicit admin remediation. The `--recovery` flag does not claim
to erase arbitrary other daemon policy on standalone hosts.

## Verification: do not confuse checks with cache hits

```sh
just check-caches
sh modules/integrations/_cache-bootstrap/bootstrap.sh probe /nix/store/HASH-NAME
```

`check-caches` compares a standalone fragment/include when present, prints the
client-visible substituters and keys, and checks a daemon connection. It explicitly
does **not** report that the daemon has accepted a substitute. Neither an HTTP
response nor `nix config show` is a daemon trust test.

`probe` must run as an ordinary user against an absent, known signed store path.
It uses `nix-store --realise` through the daemon with normal jobs, extra local jobs,
and remote builders disabled. It refuses a path already present and never deletes
store contents. Use a controlled fixture and server request logs for a conclusive
integration test; an arbitrary public cache has no promise of retaining an old
path. `HASH-NAME` above is a placeholder, not a runnable fixture.

After bootstrap, the packaged entry point is also available:

```sh
nix run .#bootstrap-cache -- check-caches
nix run .#bootstrap-cache -- sync-caches
```

The packaged app must **not** be a prerequisite for initial setup or recovery.
`packages.bootstrap-cache-conf` remains available and uses the exact same renderer
and `_cache-list.nix` inventory as the source-level path.

## Migration from the old app

The old `bootstrap-cache` app wrote `/etc/nix/conf.d/dendritic-caches.conf` without
wiring an include. The new standalone installer refuses to proceed while that
legacy file exists. Inspect whether any active file includes it, remove/migrate
only a recognized repository-owned include, and then remove the recognized legacy
file. Unknown contents require manual review; do not delete unrelated settings.
The old recipe name now requires an explicit owner and target.

When transferring a standalone host to NixOS/nix-darwin, first ensure its
declarative settings supply the policy, then remove the marked standalone include
and fragment through an administrator-approved migration. Do not leave both owners
responsible for future cache rotations.

## Tests and remaining validation

```sh
python3 modules/integrations/_cache-bootstrap/test_bootstrap.py
nix build .#checks.x86_64-linux.cache-bootstrap
# Opt-in Linux/KVM daemon/signature/rotation integration test:
nix build .#cache-bootstrap-vm-test
```

The portable tests exercise command assembly, owner/argument guards, actual
filesystem transactions, repeat execution, conflicts, parser failures, rollback,
and retired-key handling. They mock privileged commands and service/parse behaviour;
they do not activate a real host. When Lix is available, additional tests exercise
the builtins-only renderer and configuration precedence. The flake check supplies
Lix and shellcheck, validates the justfile, and compares source rendering with the
packaged configuration. Existing CI runs flake checks on Linux and macOS.

The opt-in VM test serves an HTTPS cache with disposable test keys, proves an
ordinary user's daemon substitution, and tests refusal of a fresh artifact signed
only by a retired key. It exercises a standalone-style config inside a disposable
NixOS VM, not a full non-NixOS installation or HM activation.

Before merging, run the Nix checks/formatter, the VM test, actual first activation
on supported Linux/macOS hosts, launchd restart/failure tests, and downstream
consumer validation. Record client and daemon versions separately. No private
consumer contracts or generated flake inputs are intentionally changed.

## References

- [Lix configuration loading, includes, list settings, and trust](https://docs.lix.systems/manual/lix/stable/command-ref/conf-file.html)
- [Lix multi-user daemon and root/client distinctions](https://docs.lix.systems/manual/lix/stable/installation/multi-user.html)
- [Direct expression evaluation without a flake](https://docs.lix.systems/manual/lix/stable/command-ref/new-cli/nix3-eval.html)
