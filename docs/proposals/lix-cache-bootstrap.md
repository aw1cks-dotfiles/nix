# Proposal: Lix cache bootstrap and ownership

**Status:** Draft for design review; no implementation is included.

**Scope:** First local activation and cache maintenance on NixOS, nix-darwin,
and standalone Home Manager hosts using multi-user Lix.

**Related:** [Cache rotation PR #46](https://github.com/aw1cks-dotfiles/nix/pull/46)
and [upstream outage #110](https://github.com/xddxdd/nix-cachyos-kernel/issues/110).

**Repository baseline:** `662bace7930947bc9fa3d3c5e421ff2408595422`.

## Decision

Keep declarative system configuration as the steady-state owner wherever it
exists. Bridge the first activation with command-scoped settings on NixOS and
nix-darwin. On standalone Home Manager hosts without a declarative system owner,
explicitly provision a persistent, root-owned cache fragment under `/etc/nix`.
Home Manager must not install, adopt, or update that fragment.

Use `just` as the convenient operator interface, not a bootstrap prerequisite.
The mandatory fallback uses the installed Lix executable, a shell, native system
utilities, and a reviewed local checkout. It must work before `just`, `nh`, Home
Manager, or nix-darwin is installed or any repository app has been realised.

Preserve the existing cache inventory and avoid a new platform-filtering schema,
a generic privileged command runner, or an installer framework in this change.

## Current implementation and problem

[`_cache-list.nix`](../../modules/shared/_cache-list.nix) is already a standalone
attribute set shared by the declarative settings and bootstrap app. This is the
right boundary and should remain authoritative for the repository's extra caches.

[`bootstrap-cache.nix`](../../modules/integrations/bootstrap-cache.nix) currently
realises a flake app, installs `/etc/nix/conf.d/dendritic-caches.conf`, and tries a
systemd restart. It does not establish an include from the active `nix.conf`.
Lix documents explicit includes, not automatic `conf.d` discovery. Thus a
successful file installation is not evidence that its settings were loaded. [1]

The current [`justfile`](../../justfile) calls `sudo nix run .#bootstrap-cache`
and globally exports a replacement `NIX_CONFIG`. This both requires bootstrap
tooling to be realised first and can discard caller-supplied configuration.
Its macOS detection also selects nix-darwin without distinguishing standalone HM.

[`nix-settings.nix`](../../modules/shared/nix-settings.nix) projects settings into
NixOS, nix-darwin, and HM. Upstream HM's `nix.settings` generates the user's
`$XDG_CONFIG_HOME/nix/nix.conf`, not daemon configuration. Choosing `pkgs.lix`
there does not install or replace the running system daemon. [4]

## Constraints and prior art

Lix reads system configuration, then user configuration, then `NIX_CONFIG`;
command-line options override configuration. Files require explicit `include`
or `!include`. List-valued `extra-*` settings append; they are not separate lists
that can be cleared independently. System-file values are not forwarded from
client to daemon. [1]

An untrusted client can use daemon-configured substituters and request additional
ones allowed by `trusted-substituters`; signature trust is a separate requirement.
Adding a user to `trusted-users` grants root-equivalent powers. Root may use the
local store directly unless `--store daemon` is selected. These distinctions
must be represented in the tests, not inferred from a successful root command. [2]

Cachix's `use` selects configuration according to the installation, while its
`doctor` diagnoses configuration separately. Its FAQ also describes the first
NixOS switch problem and stale daemon configuration. Adopt those ownership and
verification distinctions, without introducing a Cachix client dependency or
fetching signing keys dynamically. [3]

nix-darwin documents first activation through a fetched `darwin-rebuild` because
it is not yet on `PATH`. Cache settings therefore have to apply before realising
the activation frontend, not just to a later rebuild subprocess. [5]

These sources establish the constraints; the workflow below is a proposed design,
not a claim that an existing community tool implements it end to end.

## Ownership and supported boundary

| Explicit owner | First activation | Steady state |
| --- | --- | --- |
| `nixos` | Authorized, command-scoped cache settings for the initial system build/switch | Existing declarative `nix.settings` |
| `darwin` | Authorized settings before realising and running the pinned first-switch frontend | Existing nix-darwin `nix.settings`, with Lix system ownership enabled |
| `standalone-hm` | Administrator provisions the daemon fragment; HM then builds and activates as the target user | Persistent fragment synchronized explicitly; HM owns only user configuration |

Select the owner explicitly. OS detection is a guard, not the source of truth:
macOS can run standalone HM, and standalone HM can run on a declaratively managed
host. Existing NixOS/nix-darwin ownership must take precedence over an HM target.
An ambiguous owner, an unknown service layout, or an externally managed daemon
configuration must stop before modification.

This proposal starts with a working Lix installation and, for multi-user use, a
reachable daemon. Installing Lix itself, bare-machine provisioning, single-user
installations, Determinate-owned configuration, and remote/nixos-anywhere builds
are outside the first implementation. Report those cases explicitly; never
silently mutate another installer's files or fall back to a user-level file.
NixOS installer environments using upstream Nix need their own compatibility
check before being advertised as supported.

## 1. Break the bootstrap dependency cycle

### Render locally without evaluating the flake

Add a small, builtins-only renderer adjacent to the existing inventory, for
example `modules/shared/_render-cache-conf.nix`. It returns text, not a derivation.
It imports only reviewed local data and performs no flake evaluation, nixpkgs
import, fetch, import-from-derivation, or dependency realisation.

The intended evaluator shape is:

```sh
# Proposed renderer: this file does not exist in this documentation-only PR.
nix --extra-experimental-features nix-command \
  --option allow-import-from-derivation false \
  eval --offline --raw --file ./modules/shared/_render-cache-conf.nix
```

`nix eval --raw --file` is the documented direct-expression interface. [6]
Run rendering without privilege. Validate URLs and public-key tokens, reject
newlines/configuration injection, and never interpret rendered text as shell
code. The renderer must not require `jq`, Python, GNU-only utilities, or a
repository-provided executable.

Use the same renderer for `packages.bootstrap-cache-conf`, the optional `just`
recipes, and the documented no-`just` procedure. Preserve `_cache-list.nix`'s
current shape. Do not duplicate endpoints or rotating keys in recipes or docs.
Normal provisioning emits only the repository's extra cache URLs and keys;
recovery needs a separately explicit full-list policy described below.

### Optional recipes, mandatory direct procedure

Proposed operator interfaces, not commands added by this PR:

```sh
just bootstrap nixos '.#desktop'
just bootstrap darwin '.#<darwin-host>'
just bootstrap standalone-hm '.#<user>@<host>'
just sync-caches                 # standalone daemon owner only
just check-caches                # inspect/report; no configuration writes
```

Keep the recipes thin. Document equivalent shell commands that render, apply,
and activate with the same policy and test that fallback with `just` absent.
Do not make `nix run .#bootstrap-cache`, `nix develop`, `nix-shell -p just`, or a
network-fetched shell script a prerequisite. Later packaged helpers may remain
flake apps, consistent with the repository's tooling convention; only the
pre-realisation path is the exception.

## 2. NixOS and nix-darwin: temporary first-switch settings

Render the additional cache settings before invoking any build or flake app.
An operator-authorized invocation then applies them to both the outer command
and every Nix/Lix subprocess involved in first activation. On multi-user hosts,
use the daemon explicitly, including from root.

Treat the privilege boundary deliberately. `sudo` need not preserve environment
variables, CLI options to an outer `nix run` do not automatically become options
for its child, and root's configuration can differ from the user's. Construct a
reviewed `NIX_CONFIG` at the elevated invocation boundary, select the daemon,
and pass explicit flags where the pinned frontend requires them. Do not forward
the caller's entire environment with `sudo -E` or grant persistent trusted-user
status. Do not substitute `NIX_CONF_DIR` as a client-only daemon override.

Prefer the existing installed NixOS rebuild command and the repository's pinned
`.#darwin` app for the respective initial activations. Do not require an already
installed `darwin-rebuild` or assume `nh` is suitable for first installation.
Prove option/environment propagation for the actual pinned frontends before
advertising these recipes; a direct build alone is not an activation test.

Remove the unconditional `NIX_CONFIG` replacement from the current justfile as
part of implementation. Ordinary operations should preserve intentional caller
settings. Bootstrap should construct its explicit settings without importing
unreviewed privileged hooks or other arbitrary environment configuration.

After activation, start a fresh invocation without bootstrap overrides and verify
that declarative system settings supply the caches. Leave no bootstrap file,
include, service drop-in, or changed trust policy behind. If activation fails,
report failure without pretending ownership has transferred.

The bootstrap code should not restart a daemon for command-scoped settings;
normal system activation remains responsible for service changes. It must not
switch the configured package manager from Lix to upstream Nix as a side effect.

## 3. Standalone HM: persistent daemon provisioning

### Owned file and explicit include

Provision a regular file, not a symlink into a user checkout or an unrooted store
path:

```text
/etc/nix/aw1cks-caches.conf
```

Give it root ownership, the appropriate system group, and mode `0644`; containing
directories must not be writable by ordinary users. Record a recognizable owner
marker and inventory digest. The content is the rendered `extra-substituters`
and `extra-trusted-public-keys`, not a second hand-maintained cache list.

On a confirmed standalone Lix installation, add exactly one marked include in
the active root-owned main configuration, normally `/etc/nix/nix.conf`:

```ini
# BEGIN aw1cks cache provisioning
include /etc/nix/aw1cks-caches.conf
# END aw1cks cache provisioning
```

Use a required include, installed only after the fragment exists, so accidental
loss is visible rather than silently disabling cache policy. Do not assume that
`/etc/nix/conf.d` is scanned. If the daemon uses another configuration directory,
require an explicitly validated adapter rather than guessing from the client's
environment.

This file stays outside HM management indefinitely. HM activation never runs
`sudo`, modifies `/etc`, or restarts the daemon. Cache provisioning happens first;
HM build and activation then run as the target user. Without administrator access,
report the exact required daemon changes and stop; do not claim user config solved
host trust or run the entire HM activation as root.

### Transaction, restart, and failure handling

The installer must satisfy all of the following:

1. Show the owner, destinations, and cache/key diff before an authorized write.
   Refuse managed/store-backed main configs, unexpected symlinks, unknown existing
   fragment contents, and conflicting includes. Preserve unrelated admin settings.
2. Stage the candidate files in a root-owned directory on the destination
   filesystem, preserve main-file metadata, validate the complete configuration,
   and retain root-only backups. Treat parser warnings about unknown settings as
   failures, not merely a zero exit status. Serialize updates and detect concurrent
   edits before replacement.
3. Install the fragment atomically before adding the include. Repeated execution
   replaces only the owned fragment and does not accumulate entries. If an included
   file or later assignment changes the intended result, report the conflict.
4. Restart the verified service using a platform adapter: systemd on supported
   Linux hosts and launchd on supported macOS hosts. Handle socket-activated Linux
   daemons explicitly. A missing or unsupported manager is an actionable failure,
   not an "installed successfully" result. Do not use blanket process killing.
5. Verify a fresh daemon connection and ordinary-user substitution. If validation
   or restart fails, restore the last operational configuration and report rollback
   status. Never automatically restore a known retired/compromised key just to
   regain availability; security rotation requires an explicitly safe rollback.

Warn that restarting the daemon can affect concurrent builds. Do not claim an
online reload, or assume existing daemon connections adopted the new settings.

### Maintenance and HM client settings

`sync-caches` reuses the same renderer and transaction, shows the diff, and replaces
the entire owned fragment. It is an explicit administrator operation after an
inventory change, not an HM hook. `check-caches` reports drift without privilege
escalation; checks requiring extra permissions must be marked unverified.

The current HM adapter duplicates cache settings into the user's config. During
implementation, separate client preferences from daemon-owned cache policy for
this workflow, while preserving client Lix selection and unrelated settings.
Do not silently break consumers that deliberately use user-level cache settings;
validate a downstream consumer and provide explicit migration/opt-in behavior
before changing that reusable default.

## 4. Recovery is a separate mode

Normal bootstrap is additive. Recovery must run before realising any helper and
replace the effective cache policy rather than append to a broken one.

Require an explicit approved recovery set: by default the official NixOS cache,
with other reviewed caches selected deliberately. Supply the complete
`substituters` and `trusted-public-keys` values, retaining the official cache key
when retaining its URL. Keep the recovery baseline centralized and covered by
review/tests; never harvest signing keys from the failing endpoint.

In particular, `extra-substituters =` and `extra-trusted-public-keys =` append
nothing; they do not clear earlier additions. A later authoritative assignment
to the base setting replaces the accumulated list. [1] Apply replacement policy
after inherited configuration, reject flake-supplied configuration for that
invocation, and carry it through every child command and privilege transition.
Audit CLI arguments, user files, `NIX_CONFIG`, and service environment for paths
that could reintroduce excluded settings. Test this with an instrumented dead
endpoint rather than assuming a particular combination of flags is sufficient.

On standalone hosts, use the no-build provisioning path to repair the persisted
fragment and restart the daemon before returning to unprivileged HM operations.
Replacing the fragment alone cannot revoke a key also present in another included
file, user override, or administrator policy. Report those conflicts and require
explicit owner action; do not silently edit unrelated files.

Always retain signature checking. Do not expand `trusted-users`, accept arbitrary
flake configuration as root, or silently fall back to an expensive kernel build.
Provide a reviewed build/substitution plan; a missing substitute is distinct from
invalid trust or a dead endpoint. Cache configuration does not guarantee cache
coverage. Key removal also does not remove or revalidate existing store contents.

## 5. Verification and acceptance tests

Separate four claims: configuration parses; the expected policy is present;
the endpoint is reachable; a signed substitute is accepted by the intended daemon.
`nix config show` (or the version-appropriate equivalent) describes the invoking
client, even when a daemon store is selected; it is not a daemon-policy dump.
A daemon ping and HTTP `nix-cache-info` response also do not prove substitution.

For behavioural tests, publish a small input-addressed fixture to a controlled
local cache with an ephemeral signing key. Use a store path absent from the test
client, disable local builds and remote builders for the probe, and assert an
ordinary user's request fetches it through the daemon. Confirm the cache request
in server logs. Use distinct paths or reset fixtures for negative cases so already
valid store contents cannot mask a failed policy change. Never delete production
store paths merely to make a diagnostic conclusive.

| Required test | Evidence |
| --- | --- |
| Fresh checkout without `just`/`nh`/HM/nix-darwin | Renderer uses no fetch/build; direct procedure reaches the first activation |
| Fresh NixOS and nix-darwin | Initial frontend and children use temporary policy; a fresh post-switch invocation works without overrides |
| Standalone Linux HM + Lix/systemd | Root provisions policy; an untrusted ordinary user substitutes and activates HM |
| Standalone macOS HM + Lix/launchd | Same ownership and restart guarantees; OS alone never selects nix-darwin |
| Root and user trust boundaries | Root probe explicitly uses daemon; unapproved cache/key fails for an ordinary user; no new trusted user |
| Dead inherited cache and empty append regression | Recovery makes zero requests to the excluded endpoint, including from child commands |
| Rotation, repeated sync, and conflicting config | Old owned key disappears, new key succeeds, fresh old-key-only fixture fails; duplicates/conflicts are reported |
| Missing include, invalid config, restart failure, interrupted write | No false success; safe rollback and required-include ordering are exercised |
| Managed config, no sudo, unknown service, non-default config directory | Refusal before unsafe mutation; actionable diagnostics |
| Warm stores and missing substitutes | Diagnostics distinguish existing paths, unavailable artifacts, and successful downloads |
| Downstream consumer | Shared inventory/rendering contract works without importing public host definitions |

Record the tested Lix client and daemon versions and pinned frontend versions.
Use Linux VM tests for Linux daemon behaviour and disposable macOS hosts/runners
for launchd and first nix-darwin activation. Evaluation on Linux is not macOS
runtime coverage. Linux HM acceptance must exercise a non-NixOS-style standalone
configuration, not only the NixOS declarative daemon module.

Add narrow renderer/configuration checks to CI and run relevant existing checks;
[`nix flake check`](../validation.md) alone is not proof of these runtime flows.
Integration tests must use controlled caches rather than public cache uptime.

## Migration and implementation sequence

**First: render and prove the dependency boundary.** Add the local renderer,
no-`just` procedure, and fixture checks while preserving the existing flake output
names. Establish supported versions and explicit owner selection. No flake input,
lock pin, kernel choice, or cache-list schema change is necessary.

**Second: implement the three ownership paths.** Add thin recipes, temporary
system-bootstrap settings, and standalone daemon provisioning/sync. Keep the
shared mechanics available as packaged apps once bootstrap is complete. Do not
advertise a platform until its first-activation and daemon tests pass.

**Third: migrate and document.** Deprecate the old bootstrap app behaviour with a
clear transition. Inspect `/etc/nix/conf.d/dendritic-caches.conf` and any includes;
remove only a recognized repository-owned legacy file. If it is included, migrate
or remove that include safely before deleting the file. Unknown content requires
operator review. Transfer a standalone host to declarative ownership only after
its system config supplies the policy, then remove the owned include/fragment.

Keep implementation review separate from this design PR. Changes to shared
contracts need the repository's deeper review and downstream validation. Document
fresh bootstrap, ordinary sync, emergency recovery, and ownership transfer in the
maintained workflow docs when implementation lands.

## Deliberate exclusions and remaining implementation gates

Do not add cache auto-discovery, automatic network key trust, per-platform cache
filtering, or automatic daemon/package-manager replacement. Do not treat a cache
without binaries for the current platform as a bootstrap correctness bug.
Remote builders and installers have separate configuration/trust domains and
need a later design rather than implicit option forwarding over SSH.

The chosen architecture is settled for this proposal. Implementation still has
to prove frontend option propagation, identify supported service layouts and Lix
versions, and pass the platform matrix. Those are release gates, not assumptions
hidden in example commands.

## Validation of this proposal

This is documentation only. The existing implementation and repository guidance
were inspected, and the primary references below were checked while drafting.
No recipe, daemon file, runtime module, generated flake, or lock file is changed.
No Lix execution, full rebuild, daemon integration test, macOS activation, or
private downstream validation was performed for this proposal.

## References

Primary references reviewed on 2026-10-25. Moving documentation links describe
semantics, not a substitute for recording tested implementation versions.

1. [Lix configuration reference: loading, includes, flags, and list semantics](https://docs.lix.systems/manual/lix/stable/command-ref/conf-file.html).
2. [Lix multi-user mode: daemon selection and trust model](https://docs.lix.systems/manual/lix/stable/installation/multi-user.html).
3. [Cachix FAQ: configuration ownership, first-switch limitation, and diagnostics](https://docs.cachix.org/faq).
4. [Home Manager `nix` module on the repository's release line](https://github.com/nix-community/home-manager/blob/release-26.05/modules/misc/nix.nix).
5. [nix-darwin installation instructions](https://github.com/nix-darwin/nix-darwin/blob/master/README.md#step-2-installing-nix-darwin).
6. [Lix `nix eval`: direct files, raw output, and offline evaluation](https://docs.lix.systems/manual/lix/stable/command-ref/new-cli/nix3-eval.html).
