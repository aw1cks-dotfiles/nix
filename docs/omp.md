# OMP settings and storage

## Declarative settings and runtime edits

Declare shared or host-specific settings under `modules.ai.omp.settings`.
Additive `programs.omp.settings` declarations remain supported. The AI module
composes these with selected skills into an immutable Nix-store overlay.

Always launch `config.programs.omp.package`: its `omp` executable applies the
overlay, including from Tern, Avante, Zed, and child OMP processes.
`modules.ai.omp.package` selects the upstream package to wrap. The wrapper retains
upstream assets and exposes `unwrapped` and `managedSettings` passthru values.

The launcher replaces inherited generations of its own overlay in
`PI_CONFIG_FILES`. Explicit caller overlays remain later in that list and can
override it; CLI `--config` files can also override it. The managed overlay
outranks project and global settings, but is not a security boundary.

OMP owns the writable `agent/config.yml` (or `config.yaml`) beneath the active
config root. Activation does not create, rewrite, prune, or back up that file.
`/settings` and `omp config set` can persist global edits, but managed keys remain
shadowed by the overlay. Removing a declaration exposes any global value still
present, including values left by the old activation. Change managed keys in Nix.

### One-time cleanup of the old generated settings

Capture wanted UI edits in Nix first. With OMP stopped, back up the old generated
main config and start a private, writable runtime layer. This is independent of
whether storage is legacy or XDG. Set `runtime` to the **currently active** file;
use `config.yaml` instead if that is the file in use:

```sh
runtime="$HOME/.omp/agent/config.yml" # XDG: "$HOME/.config/omp/agent/config.yml"
(
  set -eu
  umask 077
  test ! -e "$runtime.before-overlay"
  test ! -L "$runtime.before-overlay"
  mv "$runtime" "$runtime.before-overlay"
  printf '{}\n' > "$runtime"
)
```

Copy any wanted **unmanaged** settings back from the backup by hand. Do not copy
the obsolete `task.isolation.mode` key. Skip this reset if the prior overlay
transition already cleaned the file or you have reviewed it manually. Keep the
backup private; it may contain sensitive settings. A former store symlink can
remain in the backup, but the active file must be a writable regular file.
Failed global saves can block session transitions, not just settings updates.

## Storage contract

`modules.ai.omp.storage` is:

- `"legacy"` (default): preserve the existing environment and upstream routing.
- `"xdg"`: set the user config root to `${config.xdg.configHome}/omp`, provide
  missing XDG data/state/cache homes from Home Manager, and create those three
  `omp` directories on launch. Existing files must be moved **before** launching.

`mbp` opts into XDG mode; other hosts and downstream consumers do not implicitly
opt in. Activation never moves user configuration, databases, or sessions.

| XDG location | Contents |
| --- | --- |
| `${config.xdg.configHome}/omp/agent` | Writable main config, MCP/LSP config, themes, authored skills |
| `$XDG_DATA_HOME/omp` | Auth/history/model/skill databases, sessions, blobs, prediction data, plugins, stats |
| `$XDG_STATE_HOME/omp` | Logs, markers, terminal sessions, custom session files, operational state, daemons |
| `$XDG_CACHE_HOME/omp` | Tool/document/model caches, web cache, Puppeteer, native addons |
| `$HOME/.omp/wt` | Existing worktrees, retained to preserve absolute Git/session references |

The launcher respects explicit XDG data/state/cache homes, `PI_NATIVES_DIR`, and
`OMP_WORKTREE_DIR`. Native addons default to `$XDG_CACHE_HOME/omp/natives`.
`PI_CONFIG_DIR` comes from Home Manager; its config home must be strictly inside
the user home. Unset `PI_CODING_AGENT_DIR`, which bypasses native category routing.
Keep configuration directories writable: device/install identity also lives there.
Runtime sockets use the state category, not `XDG_RUNTIME_DIR`.

A small launch guard refuses a remaining `~/.omp/agent` or symlinked `~/.omp`.
It is not proof of a complete migration: the operator owns backup, quiescence,
path selection, and completion. Migration and recovery are manual; already-moved
stores need no repeat migration.

The XDG package retains a narrow upstream patch separating project `.omp` plugin
registry discovery from the relocatable user root. Custom upstream packages must
support that source patch. Tern receives the active agent directory separately
through its `omp_dir` setting.

## Manual move to XDG

These commands describe the pinned OMP 18.19 default-profile layout. Run them in
an ordinary **Bash** shell, not inside an OMP session. Stop all OMP sessions,
editor/Tern agents, workers, and daemons first, and keep them stopped throughout.
Do not stop Tern itself if it has no OMP agents. Take an offline backup before
moving anything; do not copy a live SQLite database.

Build the new generation without activating it first (for mbp):

```sh
nix build --no-link .#darwinConfigurations.mbp.system
```

Use the same absolute roots as Home Manager and the eventual launch environment.
For non-default paths, change these assignments. Do not use overlapping roots,
symlinked roots, mounted subtrees, or this recipe for named profiles/custom agent
directories; keep legacy mode until you have planned their separate layout.

```bash
set -euo pipefail
umask 077
shopt -s nullglob dotglob
legacy="$HOME/.omp"
config="${XDG_CONFIG_HOME:-$HOME/.config}/omp"
data="${XDG_DATA_HOME:-$HOME/.local/share}/omp"
state="${XDG_STATE_HOME:-$HOME/.local/state}/omp"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/omp"
backup="$HOME/omp-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$backup"
tar -czf "$backup/legacy.tgz" -C "$HOME" .omp
```

The backup contains credentials; keep it private and outside version control.
For a fresh home with no existing OMP files, skip the move entirely. If data,
state, and cache have **already** been moved, skip the next block, back those
roots up too, and go directly to the configuration move. Never merge populated
old and new stores. If either tree has acquired newer writes, reconcile those
before proceeding.

### Move categorized storage (only when still legacy)

All destinations, including config, must be absent. If a destination already
exists, stop and inspect it rather than deleting it or rerunning blindly. These
commands move complete directories and SQLite sidecars together while OMP is
offline. Prefer the same filesystem; `mv` across filesystems becomes copy/delete
and is not atomic. There is no automatic recovery after an interrupted sequence.

```bash
for target in "$config" "$data" "$state" "$cache"; do
  test ! -e "$target"
  test ! -L "$target"
done

# Missing optional files are normal. Never overwrite a destination entry.
move_into() {
  local destination=$1 source target
  shift
  mkdir -p "$destination"
  for source in "$@"; do
    if [ ! -e "$source" ] && [ ! -L "$source" ]; then continue; fi
    target="$destination/${source##*/}"
    test ! -e "$target"
    test ! -L "$target"
    mv "$source" "$target"
  done
}

move_into "$data" \
  "$legacy"/{plugins,remote,remote-host,python-env,browser-relay,marketplaces.json} \
  "$legacy"/{autoqa,stats}.db{,-wal,-shm,-journal} \
  "$legacy/agent"/{agent,history,models,skill-descriptions}.db{,-wal,-shm,-journal} \
  "$legacy/agent"/{predict,sessions,blobs}
move_into "$state" \
  "$legacy"/{reports,update,logs,ssh-control,browser-profiles,autoresearch,security,run} \
  "$legacy/agent"/{python-gateway,last-changelog-version,memories,terminal-sessions,custom-session-files,omp-crash.log,omp-debug.log,secret-placeholder.key}
move_into "$cache" "$legacy"/{puppeteer,webcache,natives}
move_into "$cache/cache" "$legacy/cache/"* \
  "$legacy/agent/cache"/{tiny-models,document-conversions} \
  "$legacy/agent/cache/composer.db"{,-wal,-shm,-journal}
# The root cache has been emptied; any unknown agent/cache entries stay with config.
if [ -d "$legacy/cache" ]; then rmdir "$legacy/cache"; fi
```

### Move configuration (also for already-migrated storage)

First ensure the category roots contain the expected databases, sessions, and
blobs. For already-migrated storage, make separate offline snapshots now:

```bash
# Optional when these roots were absent in the legacy backup above;
# required before changing an already-migrated installation.
tar -czf "$backup/data.tgz" -C "$data" .
tar -czf "$backup/state.tgz" -C "$state" .
tar -czf "$backup/cache.tgz" -C "$cache" .
```

Move the remaining tree, including identity, authored skills, hidden files, and
unknown files. Leave `wt` at its original absolute path. Do not create a
compatibility symlink. If config is already at the intended XDG location, skip
this block too:

```bash
test ! -e "$config"
test ! -L "$config"
mkdir -p "$config"
for source in "$legacy/"*; do
  [ "${source##*/}" != wt ] || continue
  mv "$source" "$config/"
done
```

Apply the settings cleanup above if still needed, then activate normally:

```sh
nix run .#rebuild -- . -H mbp --no-nom
```

Open a fresh shell and run `omp config path` and `omp config get composer.shape`.
On mbp these should report `$HOME/.config/omp/agent` and `borderless`. Verify
credentials without printing secrets, resume an existing session, resolve its
blobs, and exercise a session/worktree transition after a runtime settings edit.
Check MCP/LSP, authored/Nix-selected skills, project plugins, and Tern/editor
launches before accepting the move.

### Recovery

Keep OMP stopped. An interrupted move requires inspection of both source and
destination; do not launch either layout until it is complete. To abandon a
move, preserve the new trees outside the active paths and restore the offline
backup. For a completed full legacy-to-XDG move:

```bash
# Use the same variables and backup directory as the move; do not overwrite an
# earlier recovery attempt. Preserve later writes rather than deleting them.
for name in legacy config data state cache; do
  test ! -e "$backup/after-$name"
  test ! -L "$backup/after-$name"
done
if [ -d "$legacy" ]; then mv "$legacy" "$backup/after-legacy"; fi
mv "$config" "$backup/after-config"
mv "$data" "$backup/after-data"
mv "$state" "$backup/after-state"
mv "$cache" "$backup/after-cache"
tar -xzf "$backup/legacy.tgz" -C "$HOME"
```

For a **config-only** move, leave data/state/cache in place; preserve the new
config and restore `legacy.tgz` instead. Restore the previous generation before
launching. Simply setting `storage = "legacy"` is not sufficient if XDG category
roots remain: upstream can still select them from the environment. Restoring a
snapshot does not incorporate newer writes; the preserved `after-*` trees are
for manual reconciliation, never concurrent writers.

## Validation and upstream references

See [validation](./validation.md#omp-settings-and-storage) for focused checks.
No live move or switch is implied by a package/check build. Downstream consumers
must validate their actual composed package before rollout.

- [Settings and overlays](https://github.com/can1357/oh-my-pi/blob/main/docs/settings.md#where-settings-live)
  and [configuration discovery](https://github.com/can1357/oh-my-pi/blob/main/docs/config-usage.md).
- [Directory routing](https://github.com/can1357/oh-my-pi/blob/main/packages/utils/src/dirs.ts)
  is the source of the category mapping above. `omp config init-xdg` only creates
  directories; it does not move existing files.
- [PR #407](https://github.com/can1357/oh-my-pi/pull/407#issuecomment-4060586041)
  explains why automatic migration was removed upstream.
