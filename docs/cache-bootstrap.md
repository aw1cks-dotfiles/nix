# Cache bootstrap (draft implementation)

This workflow configures caches **before** the first activation. It does not
install Lix. It requires a working multi-user Lix installation, **Python 3.9 or
newer**, administrator access for host changes, and a reviewed local checkout.
No `just`, `nh`, Home Manager, nix-darwin CLI, flake evaluation, or application build
is needed to render the cache policy.

The implementation is a draft. Python transaction tests use service doubles;
first NixOS/nix-darwin/HM activation and launchd behaviour still require disposable
host validation. Do not treat the available recipes as a completed cross-platform
certification.

Install a security-supported Python build through the host's approved provisioning
mechanism before starting. Python 3.9 is the language compatibility floor, not a
recommendation to install an unsupported upstream release; older versions must be
maintained by the OS/vendor. The source entry point uses only the standard library
and never fetches an interpreter through Nix. The packaged app supplies pinned
Python after bootstrap. The former shell implementation has been removed; both
entry points execute the same Python code.

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

The helper resolves the directory and runs the frontend with that explicit working
directory and a `.#name` reference. Lix retains normal Git-aware source selection:
Git-ignored/untracked files and `.git` are not copied into the store. Track required
configuration files before bootstrap. Non-Git flakes retain normal path-source
semantics, including all files in their directory. Spaces, Unicode, and literal
`%`, `?`, and `#` in checkout names are supported; the final `#` separates the output name.

## First activation, with or without just

```sh
just bootstrap nixos '.#desktop'
just bootstrap darwin '.#macbook'
just bootstrap standalone-hm '.#user@host'
```

Exactly the same source-level entry point works without `just`:

```sh
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py bootstrap nixos '.#desktop'
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py bootstrap darwin '.#macbook'
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py bootstrap standalone-hm '.#user@host'
```

Use a real output name; the macOS/HM names above are illustrative. Run standalone
HM bootstrap as the intended user, **not** with `sudo` around the whole command.
The helper requests sudo only for daemon provisioning. System activation uses an
explicit elevated environment; it does not forward arbitrary caller `NIX_CONFIG`
or use `sudo -E`. Ordinary `just` commands no longer replace the caller's config.
Private-input credentials and proxy settings from the user's environment are not
forwarded across sudo. Any required elevated access must already be configured
through approved system/root-owned settings; this helper is not a credential bridge.
The elevated Python helper resolves interpreter symlinks and refuses a binary
that is not root-owned or is group/other-writable. Use an administrator-managed
interpreter and standard library; isolation is not a substitute for runtime trust.
It uses `-I -S`: caller import paths, user/system site initialization, virtualenv
`.pth` hooks, and `sitecustomize` are not executed. The root helper receives only
the restricted fragment on stdin, not a caller-selected executable to run.

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
complete candidate configuration: the staged system file, relative admin includes,
and the standard root user configuration sources, including `/etc/xdg/nix/nix.conf`
and root's `~/.config/nix/nix.conf`. Arbitrary caller overrides are not forwarded.
Configuration inspection runs explicitly offline, so recovery and network-isolated
checks do not depend on interface detection. Cache URLs, signing keys, and
signature-policy validation are unchanged. Parser warnings and disabled signature
checking remain failures. Partial or manually edited owned blocks require operator
review.

Updates are serialized under a lock before inspecting the current files.
**Enrollment** installs the fragment before adding the include to `nix.conf`,
preserving its ownership, mode, supported standard-library metadata, and unrelated
settings. **Synchronization** atomically replaces only the fragment; it never
rewrites `nix.conf`, even during rollback. Trailing comments, file identity, and modification
time of the main configuration are preserved during synchronization.

Provisioning validates the **loaded service definition**, not just its disk file.
Only stock daemon commands from an immutable Lix installation are accepted:
direct `nix-daemon`, its systemd `--daemon` form, `nix daemon`, and the installer's
exact macOS `wait4path` wrapper. Arbitrary arguments, including `extra-*` and `no-*`
policy flags, and arbitrary shell wrappers are rejected. The helper discovers the
daemon installation from the loaded service, verifies its binaries and Lix versions,
then parses the candidate configuration and checks liveness with its matching `nix`.
The ordinary user's client may come from another Lix installation. Client and daemon
installation versions are reported separately; provisioning does not replace either.

On systemd, loaded properties, `NeedDaemonReload`, unit files, and manager/service
environments are inspected. On launchd, loaded arguments and environment must agree
with the secure plist; system-domain environments are inspected too. Overrides of
configuration sources (`NIX_*` other than the standard TLS certificate path, `HOME`,
or XDG configuration directories) stop provisioning. Unknown or ambiguous launchctl
output fails closed because its diagnostic format is not a stable API.

The validated service is checked again before restart (`nix-daemon.service` on
systemd, `system/org.nixos.nix-daemon` on launchd), then a fresh connection is checked.
Socket activation is handled by starting/restarting the service, rather than
skipping the operation when it was previously inactive. Restarts can interrupt
other builds. A changed definition requires operator review; the helper does not
reload unrelated service configuration automatically.

Root-only transaction backups are kept under `/etc/nix/.aw1cks-caches.*` when
files were changed. On an ordinary failure, modified files are restored and
restart is retried. A failure before fragment replacement reports that the old
policy remains installed. **After a replacement removes a cache/key, failure does
not silently restore retired trust**: the new fragment stays installed, the
operation fails, and an administrator must inspect the reported backups and
service state. Persistence does not establish which policy a failed daemon is
using. Cleanup reconciles interrupted renames before choosing a rollback.

There is no promise of crash-atomicity across the two enrollment files; include
ordering and backups make an interrupted enrollment recoverable. An abandoned
`.aw1cks-caches.lock` must be inspected before manual removal.

HM never owns this daemon fragment and never runs sudo as an activation hook.
The existing HM client settings/package selection are preserved for compatibility;
they are not a replacement for daemon trust. This change does not reinstall the
system Lix daemon merely because HM selects `pkgs.lix` for the client.

## Synchronization and recovery

After a cache URL or signing-key change, standalone hosts need an explicit sync:

```sh
just sync-caches
# Without just:
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py sync-caches
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
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py --recovery bootstrap nixos '.#desktop'
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
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py probe /nix/store/HASH-NAME
```

`check-caches` compares a standalone fragment/include when present, prints the
client-visible substituters and keys, and checks a daemon connection. It explicitly
does **not** report that the daemon has accepted a substitute. Neither an HTTP
response nor `nix config show` is a daemon trust test.

`probe` must run as an ordinary user against an absent, known signed **output**
store path. It rejects `.drv` paths and explicit output selections before invoking
`nix-store --realise`. Plain output paths use Lix's substitution-only operation;
normal jobs and remote builders are also disabled. It does not rely on an
untrusted client being allowed to change `extra-local-jobs`. It refuses a path
already present and never deletes store contents. Use a controlled fixture and
server request logs for a conclusive integration test; an arbitrary public cache
has no promise of retaining an old path. `HASH-NAME` above is a placeholder, not a
runnable fixture.

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
python3 -B -m unittest discover -s modules/integrations/_cache-bootstrap -p 'test_*.py' -v
nix build .#checks.x86_64-linux.cache-bootstrap
# Opt-in Linux/KVM daemon/signature/rotation integration test:
nix build .#cache-bootstrap-vm-test
```

The VM test needs hardware acceleration. Where the build users cannot open
`/dev/kvm` (typical on a multi-user Linux install, where the device is
`root:kvm 0660` and `nixbld` is not in `kvm`), QEMU silently falls back to TCG
emulation; pass `--option sandbox false --option build-users-group ''`, or grant
the build users access to the device, before recording a KVM result.

The tests exercise argument guards, actual source rendering and Lix configuration
parsing, real Lix evaluation of checkout names containing URL-reserved characters,
Git-aware source boundaries for ordinary checkouts, nested flakes and worktrees,
temporary-filesystem transactions, repeat synchronization, retained-key conflicts,
rollback, and interruption on either side of each commit rename. Service tests
cover independent client/daemon installations and reject policy arguments,
manager/service environment overrides, stale definitions, ambiguous inspection
output, and changes between validation and restart.
Real PTY interaction covers approval and default rejection; a virtualenv startup-hook
fixture verifies that interpreter-relative customization cannot cross the privilege boundary.

Ownership and service operations use doubles; tests do not activate a real host.
Renderer and transaction tests require installed Lix and are skipped when unavailable.
Extended-attribute preservation is checked where Python and the filesystem expose it;
the implementation does not promise macOS ACL preservation beyond standard-library
capabilities. The flake check supplies Python, Lix and Git, discovers all Python regressions,
validates the justfile, and compares source rendering with the packaged configuration.
Existing CI runs flake checks on Linux and macOS.

The opt-in VM test serves an HTTPS cache with disposable test keys and exercises
the actual ordinary-user `probe` entry point. It covers substitution, rejection
of derivation inputs and fresh artifacts signed only by a retired key, refusal
of conflicting root defaults, and preservation of the main configuration during
sync. It uses a standalone-style config inside a disposable NixOS VM, not a full
non-NixOS installation or HM activation.

Before merging, run the Nix checks/formatter, the VM test, actual first activation
on supported Linux/macOS hosts, launchd restart/failure tests, and downstream
consumer validation. Record client and daemon versions separately. No private
consumer contracts or generated flake inputs are intentionally changed.

## References

- [Lix configuration loading, includes, list settings, and trust](https://docs.lix.systems/manual/lix/stable/command-ref/conf-file.html)
- [Lix multi-user daemon and root/client distinctions](https://docs.lix.systems/manual/lix/stable/installation/multi-user.html)
- [Direct expression evaluation without a flake](https://docs.lix.systems/manual/lix/stable/command-ref/new-cli/nix3-eval.html)
