# Architecture

This repo is both a reusable public Nix library and a small live-config repo for a few public hosts.

The stable split is:

- reusable schema, constructors, profiles, and integrations live under `modules/`
- repo-local host composition roots live under `hosts/`
- downstream starter material lives under `templates/default/`

## Generated Flake

`flake.nix` is generated.

The source of truth is `modules/flake-file.nix`, which:

- imports `inputs.flake-file.flakeModules.default`
- imports `modules/_internal/flake-file-inputs`
- exports `flakeModules.default`
- exports `flakeModules.downstream-flake-file`
- exposes `templates.default`

The hidden `modules/_internal/flake-file-inputs/default.nix` file is the reusable downstream `flake-file.inputs.*` contract. Runtime consumers of those inputs live in visible modules under `modules/integrations/`.

### Operational entry points

Shared flake apps are the canonical interface: `nix run .#rebuild`,
`nix run .#update -- [inputs...]`, `nix run .#clean -- [days]`, and `nix run .`
for the default rebuild app. Update forwards input names and flags to
`nix flake update` (except checkout-changing `--flake`) and
regenerates the flake at the repository root, then archives all input sources
into the local store. Only update performs best-effort GitHub authentication;
rebuild does not inject credentials into NH. Clean defaults to 7 days and accepts
`--gc-only` or `--optimise-only` for the separate operations. There is no
justfile: the apps are the only operational interface, so nothing duplicates
their logic outside Nix.

Initial cache bootstrap and break-glass recovery are deliberately source-based:
`python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py` runs from a
reviewed library source checkout without first evaluating the flake or building
an app. The downstream template does not bundle this Python implementation.
See [cache bootstrap](./cache-bootstrap.md).


## Repo Layout

- `modules/schema/`: option schemas for shared namespaces and constructor contracts
- `modules/constructors/`: host constructors for `configurations.nixos`, `configurations.darwin`, and `configurations.home`
- `modules/constructors/_lib.nix`: small shared constructor helpers
- `modules/integrations/`: pinned apps, packages, and flake-input runtime consumers
- `modules/shared/`: cross-target reusable modules
- `modules/home/`, `modules/darwin/`, `modules/nixos/`: target-specific reusable modules and profiles
- `modules/roles/defaults.nix`: role-to-profile mapping used by constructors
- `hosts/default.nix`: explicit host loader for repo-local host roots
- `hosts/facts.nix`: normalized shared host metadata module
- `hosts/<name>/configuration.nix`: repo-local host composition roots
- `hosts/<name>/*.nix`: host-private support files imported by that host root when needed

The reusable Neovim module configures Avante.nvim to use OMP through ACP; see
[Avante.nvim with OMP ACP](./avante-omp.md) for its operational contract.

`aw1cks.modules.home.language-servers` provisions the shared server packages in
Home Manager's user environment; `aw1cks.profiles.home.developer` includes it.
Neovim reuses the same package list in its private wrapper PATH without requiring
the developer profile. Server configuration and discovery remain client-owned.

OMP additionally needs a generated `~/.omp/agent/lsp.json`, because its built-in
definitions do not match several nixpkgs server names and omit others;
`aw1cks.modules.home.ai` owns that file. See
[shared language-server packages](./neovim.md#shared-language-server-packages).

## Tern

`aw1cks.modules.home.tern` defines opt-in `modules.tern` settings and independently
opt-in `services.tern.daemon` / `services.tern.remote`. The desktop profile imports
the definitions without enabling them. The public `mbp` host enables both services.

Tern 0.9.13 is packaged by this flake and selected automatically on macOS arm64,
Linux x86-64 and Linux arm64. The unrelated nixpkgs `tern` package is not this
terminal. After importing the authenticated archive below, a home can simply use:

```nix
{
  modules.tern.enable = true;
  services.tern.daemon.enable = true;
}
```

### Binary packages and manual import

The closed-beta build service requires an interactive login. Nix never stores
download credentials or tries to fetch a login page: `requireFile` pins the
archive's exact filename and flat SHA-256, and tells you how to supply it when
missing. The reviewed pins live in
[`modules/integrations/_tern-sources.nix`](../modules/integrations/_tern-sources.nix).

| Nix system | Required upstream archive |
| --- | --- |
| `aarch64-darwin` | `Tern-0.9.13-macos-arm64.zip` |
| `x86_64-linux` | `Tern-0.9.13-linux-x86_64.tar.gz` |
| `aarch64-linux` | `Tern-0.9.13-linux-arm64.tar.gz` |

1. Sign in at <https://build.stencil.so/tern> and download the pinned version for
   the build host. Use the full macOS application ZIP, or the Linux **glibc**
   tarball, not the musl build.
2. Keep the exact filename above (remove any browser-added duplicate suffix).
3. On the machine that will build it, import the archive. For example on amd64:

   ```sh
   archive="$HOME/Downloads/Tern-0.9.13-linux-x86_64.tar.gz"
   nix hash file --type sha256 --sri "$archive"
   nix-store --add-fixed sha256 "$archive"
   nix build .#tern
   nix run .#tern -- --version
   ```

   The printed hash must match the platform's pin. Importing a differently
   named or different-version file does not satisfy `requireFile`.
4. Rebuild Home Manager. Remove a previous `modules.tern.executable` override to
   select the packaged binary. Existing constructors allow unfree packages;
   independent Home Manager package sets must permit this unfree application.

Repeat the import for each independent build machine/store. Downloading all
three archives on a Mac does not seed a Linux machine's store. Transfer the
archive and import there, or copy the returned source store path to a private
builder with `nix copy`. Keep the original download: an unreferenced source may
be garbage-collected and need importing again. Neither downloads nor user state
are moved or deleted by the package.

The macOS package preserves the signed/notarized `Tern.app` under
`$out/Applications`, with an external CLI wrapper; it does not strip, patch or
re-sign the application. Use the ZIP rather than a DMG so no disk-image extraction
is needed. Verify an installed package after store registration:

```sh
package="$(nix build .#tern --no-link --print-out-paths)"
codesign --verify --deep --strict "$package/Applications/Tern.app"
"$package/bin/tern" --version
```

Do not execute the signed bundle inside its Nix builder: macOS can attach
app-management metadata before output canonicalisation. Version/signature checks
on Darwin run after registration. Linux uses `autoPatchelfHook`, declared
graphics/windowing/WebKit/audio libraries, runtime helper wrappers and the real
upstream icons; both Linux architectures share the same native packaging logic.
Non-NixOS Linux still needs the existing Home Manager generic GPU setup to
provide host-compatible drivers at `/run/opengl-driver`.

Packaged Tern disables its self-updater. Update the version and all source hashes,
import the new archives and rebuild instead; running daemons adopt the new
executable on their next start without an automatic destructive restart.
These authenticated unfree artifacts are not added to public CI builds or the
public cache closure. Do not commit or redistribute archives/binaries without
permission from the licence holder.

Once verified, an old manually installed `~/.local/bin/tern` should be retired so
it cannot shadow the package on shell PATH. Nothing removes it automatically.
For a deliberate external install, set `modules.tern.package = null` and an
absolute `modules.tern.executable`; that remains separate from the packaged default.


Use `tern`, **Tern Managed.app** on Darwin, or **Tern Managed** on Linux.
The Home Manager profile gives its managed `tern` launcher higher priority than
the package's raw CLI; there is no separate `tern-managed` command. It sets
`TERN_CONFIG_DIR` and `TERN_DAEMON_SOCKET`, then executes the selected backend by
absolute path, never by looking up `tern` on PATH. This avoids recursion and keeps
CLI/GUI clients on the same daemon, including custom paths. Do not point
`modules.tern.executable` at the managed profile command.
Linux's application/file/URL desktop IDs also route through this launcher.
Launching the raw upstream application directly does not inherit custom managed
environment settings.
The default config directory is `~/Library/Application Support/Tern` on Darwin
and `$XDG_CONFIG_HOME/tern` on Linux. Setting `TERN_CONFIG_DIR` also places Tern's
application state there; it is not a read-only configuration directory.
`modules.tern.socket` is the one socket option for launchers and services.
Its absolute path must fit the platform's Unix-domain socket limit.

### Keyboard, links and appearance

Primary means Command on Darwin and Ctrl+Shift on Linux. Primary + physical
left/right bracket splits right/down; Primary + arrows focuses a pane;
Primary + T creates a tab; Primary + 1–8 selects a tab and Primary + 9 selects
the last tab. Physical keys preserve these positions on non-US layouts.
Darwin also keeps the physical Ctrl+Shift digit aliases from WezTerm.

The prefix is **Shift+Space**, released before the following unmodified key:

| Following key | Action |
| --- | --- |
| Arrow | Resize the split |
| `[` / `]` | Previous / next pane |
| `,` / `.` | Previous / next tab |
| `k` / `j` | Previous / next shell prompt (`k` also preserves contextual reply-start navigation) |
| `b` / `f` | Browser back / forward |
| `p` / `u` | Park pane / show parked panes |
| `s` | Session switcher |
| `t` | New shell block |

Shift+Space is reserved; it no longer inserts a space. Ordinary Space is unchanged.
Configure `keyboard.prefix`, `keyboard.primaryModifier`, or disable the map with
`keyboard.enable = false`. `settings.keybinds` overrides individual generated
bindings; an empty action list unbinds a chord. Other native Tern bindings remain.

New agent blocks open in a new tab, including Command+Shift+A on Darwin and
Ctrl+Shift+A on Linux. Set `settings.agent_placement` to `split` or
`replace_if_alone` to change that native placement policy.

Darwin defaults `keyboard.optionAsAlt = "left"`: Left Option sends native Alt/Meta
for Readline and other terminal programs; Right Option retains accents and layout
characters. This explicitly avoids Tern's layout-dependent Auto setting.
Linux keeps native Alt handling. Tern opens web links internally; Alt/Option with
the link-opening click selects the default external browser. If links require
Command-click, use Option+Command-click. File links remain in Tern.

Terminal/code fonts use `aw1cks.fonts.defaults.monospace` (CaskaydiaMono first);
UI fonts use `aw1cks.fonts.defaults.sansSerif` (SF Pro first), provisioned by the
existing desktop font modules. Weight defaults to Medium (500). Tern uses the
same nominal terminal size as WezTerm, capped at 32px, without an extra DPI
conversion. UI size defaults to two pixels below the terminal size (minimum 8px):
the shared defaults are 18px terminal / 16px UI.
Padding is terminal-content padding in whole pixels, defaulting to 16 horizontal
and 12 vertical, with the native 0–40px range.

The terminal cursor defaults to a blinking underline. Programs may temporarily
select another shape (for example Vim's mode cursor); a reset restores the
underline. Built-in file editors retain their native caret shape.
Override these through `settings.cursor`.

`modules.tern.themes.<name>.source` installs an additional CSS theme without
selecting it. Names contain only letters, digits, underscores and hyphens.
`theme.dark` and `theme.light` independently select CSS or OMP catalog names;
null leaves that appearance's selection unmanaged. Dark defaults to
`oxocarbon-dark`; light is unmanaged by default. The module provisions the
default OMP Oxocarbon JSON without requiring OMP to run.

Each selected appearance gets an internal `nix-managed-dark.css` or
`nix-managed-light.css` wrapper. Those names are reserved. Composition order is
the selected base, the optional terminal palette, then `theme.extraCssFiles` in
list order. Later files win subject to normal CSS specificity; nothing adds
`!important`. Use `lib.mkBefore` / `lib.mkAfter` to order contributions from
different modules. There is no inline CSS option.

`theme.palette` follows the selected WezTerm scheme when imported, otherwise
the shared Oxocarbon palette. It requires `background`, `foreground`,
`cursor_bg`, eight `ansi` and eight `brights` colors; other WezTerm scheme
fields are accepted. Set it to null to preserve the selected theme's terminal
colors, especially when using a light theme. A non-null palette applies to both
selected appearances. Do not compensate values for renderer color-space bugs.

```nix
{
  modules.tern = {
    themes.company-dark.source = ./company-dark.css;
    themes.company-light.source = ./company-light.css;
    theme = {
      dark = "company-dark";
      light = "company-light";
      palette = null;
      extraCssFiles = [ ./terminal-adjustments.css ];
    };
    settings.theme = "Light"; # Defaults to Dark; native settings remain overridable.
  };
}
```

Theme assets install even with `theme.enable = false`; that switch controls
wrappers and generated selection settings only. Raw `settings.theme_dark` and
`settings.theme_light` overrides bypass wrapper selection and its CSS layers.
Prefer `theme.dark` / `theme.light` when composing additional CSS.

The shared Tern module prepends `_tern/quiet-grip.css` to `extraCssFiles` with
`lib.mkBefore`, so downstream consumers inherit the quieter pane grip without
host-local wiring. It stays centered but is smaller, transparent and lifted
into the top inset, clear of the first row at the default fonts and padding.
Hover/focus reveal a compact outline; native resting auto-hide, menu and drag
behaviour remain. Other grip types are untouched.

Ordinary `extraCssFiles = [ ./custom.css ];` contributions append after this
default. To opt out, use `modules.tern.theme.extraCssFiles = lib.mkForce [];`,
or force a replacement list containing only your own files. Normal CSS
specificity still applies. Recheck row clearance when changing font sizes or
vertical padding.

Migration: replace `theme.base` with `theme.dark`; `theme.name` is removed because
wrapper names are internal. Home Manager removes obsolete managed theme links.
Fonts, padding and the settings escape hatch remain unchanged.

### Plugins

`modules.tern.plugins` is a mergeable registry keyed by native manifest ID:
1–32 lowercase letters, digits or hyphens, excluding reserved ID `tern`.
Every entry has `enable` (default false), `source` (required only when enabled)
and `runtimePackages` (default empty). No third-party plugins are fetched or
enabled implicitly. Public and downstream modules contribute entries through
the same contract:

The bundled registry in `modules/home/packages/_tern/registry.nix` provides:

| ID | Upstream | Included runtime |
| --- | --- | --- |
| `tern-projects` | [Projects](https://github.com/thegeneralist01/tern-projects) | Rust indexer, built by Nix rather than Cargo at first launch |
| `tern-kata` | [Kata](https://github.com/Dangerboi/tern-kata) | Go CLI and worker |
| `tern-kube` | [Kube](https://github.com/contrafy/tern-kube) | `kubectl` |
| `tern-grafana` | [Grafana](https://github.com/contrafy/tern-grafana) | None required for the basic UI |

All four remain opt-in in the shared module; the public `mbp` host enables them.
Sources are pinned by commit and hash in `_tern/plugin-sources.nix`, not additional
flake inputs. Source defaults can be replaced normally; required runtime tools
merge with downstream `runtimePackages` contributions. To replace that tool set
entirely, use `lib.mkForce`. Disabled entries do not build their sources or tools.
Helm, credential-provider executables, agent harnesses and Grafana command-lens
tools (`promtool`, `amtool`, `logcli`, `curl`) remain optional user dependencies.

After activation, open the command palette and choose Projects, Open kata,
Tern Kube Settings/Explore, or Tern Grafana Query/Settings. Projects' upstream
Command+Option+S binding collides with a native preset on Tern 0.9.13; use the
palette rather than relying on that shortcut. The separate [Kata service](#kata)
below supplies `mbp`'s local backend; other hosts need their own local or remote
Kata daemon. Kube uses your kubeconfig, and Grafana needs backend contexts in
`~/.config/tern-grafana/config.json`. Loading a plugin alone does not configure
these services or credentials. Plugin actions retain upstream permissions and mutation
defaults; enabling Kube is not a read-only cluster policy.

Update the pinned sources and dependency hashes to update managed plugins;
upstream installers cannot replace Home Manager's linked packages. Projects may
still check for upstream releases and notify; its indexer never compiles at
runtime in this package. Do not put credentials in the store-backed sources.

Public and downstream registry modules can also contribute their own entries:

```nix
# A registry module: use a pinned input or a reviewed local source directory.
{ inputs, lib, ... }: {
  modules.tern.plugins.company-tools.source =
    lib.mkDefault (inputs.company-plugins + "/tern/company-tools");
}
```

A profile may set `plugins.company-tools.enable = lib.mkDefault true` under
`modules.tern`. A consuming host can set it to false without `mkForce`, enable
other registry entries, or supply its own:

```nix
{ pkgs, ... }: {
  modules.tern.plugins = {
    company-tools.enable = false;
    local-tools = {
      enable = true;
      source = ./plugins/local-tools;
      runtimePackages = [ pkgs.git ];
    };
  };
}
```

Sources enter the immutable Nix store. Build-time validation checks the upstream
`plugin.toml` schema, matching ID, host/window entry files, stylesheet paths and
source containment without executing plugin code. Home Manager owns individual
`plugins/<id>.path` pointers, never the entire writable plugins directory.
Disabling a managed entry removes its pointer, not mutable plugin data or
manually installed plugins. Before `writeBoundary`, a read-only migration guard
checks existing source directories, symlinked directories and `.path` aliases
by manifest ID. A copy that would shadow an enabled managed plugin aborts
activation with an explicit migration error, even when its filename differs.
Move the old source and any alias pointer outside the active plugins directory
yourself; keep plugin data intact. Nothing is deleted, adopted or executed.
The exact managed `<id>.path` slot remains under Home Manager's normal
ownership/collision handling so generation updates work. Unreadable candidates
fail closed; hidden entries and obvious invalid/nonpackages are ignored.

Enabled runtime packages enter the home profile and are prepended to managed
GUI/CLI and service PATHs after configured environment overrides. The profile's
`bin` directory is also included so plugin subprocesses can invoke the managed
`tern` CLI. Changes apply to newly started processes; activation does not restart
sessions or reload plugins. Run `tern plugin reload` explicitly to update a
running daemon's plugin set. A running GUI may retain its previous environment
until reopened.

Plugins are trusted code with filesystem, process and network APIs. Their host
half runs on the daemon's machine, their window half in the local GUI; configuring
a client does not deploy plugins to a remote server. Window-only `tern.css`
styles do not reach web clients; upstream manifest `styles` do. Plugin-specific
configuration remains the plugin's responsibility; this contract does not
invent a generic settings or secrets format.

### Writable settings ownership

Home Manager links the theme, not `settings.json`. Activation atomically merges
the declared settings into that writable JSON file, preserving unrelated fields
such as SQLite recents and custom keybindings. `modules.tern.settings` overrides
generated defaults; its contents enter the Nix store, so do not put secrets there.
Only declared leaves are owned. Removed declarations remove their formerly owned
leaves/chords rather than leaving obsolete prefix bindings behind.

The private `.nix-settings-state.json` records ownership and interrupted-commit
recovery. Do not edit it. Malformed JSON and output symlinks fail without replacing
settings. An interrupted merge with subsequent external edits fails closed:
preserve both files and resolve the ambiguity before applying again.
Reapplying unchanged settings does not rewrite the file.

Preferences are merged after file linking and before launchd/systemd service
startup, so newly started services cannot read the previous settings generation.

Quit Tern's GUI before rebuilding to avoid racing its preference writes, then
reopen it to load the changed preferences; the daemon need not be restarted.
No application shutdown or reload is forced. GUI changes to managed values last
until the next
activation. Disabling the entire feature preserves mutable settings/state;
disable individual generated settings and activate once first if their owned
values should be removed. User state, keys and histories are never garbage-collected.

### User services and migration

The local session daemon and remote server are different processes. Both use
launchd agents on Darwin and systemd user units on Linux; neither runs as root.
Remote serving is opt-in and always uses `remote serve --user`.
Relay use is explicitly disabled with `--relay none`, not merely omitted.

Remote options include `listenAddress`, `port`, `stateDirectory`, `accessFile`,
`authorizedKeysFile`, and `relay.{enable,url,caFile}`. Its listener defaults to
loopback; the Mac host explicitly retains direct access on `0.0.0.0:8376`.
No firewall or Linux lingering policy is changed. Relay-disabled does not mean
network-disabled. Access policy, authorized keys, certificates and credentials
remain mutable files outside the Nix store.

Each service has `autostart`, `environment`, `extraArgs`, `restartPolicy`, and
`restartDelay`. Module-owned flags cannot be replaced through `extraArgs`.
The local daemon defaults to `always` so native idle exit does not leave it
unavailable; choosing `on-failure` permits idle exit and requires manually
restarting the managed service afterwards. Remote defaults to `on-failure`.

Before the first switch, preserve or close active sessions, quit Tern, and
explicitly disable/unload the old native or installer supervisor. Activation
only inspects known old labels/units and fails before changing files if they are
still registered; it never boots them out. On Linux it also fails if systemd
cannot be inspected, including an unreachable user manager. Custom third-party
supervisor names must be retired manually too.

Darwin's old labels are `so.stencil.tern.daemon`, `so.stencil.tern.login` and
`so.stencil.tern.remote`. Linux checks `tern-daemon.service` and
`tern-remote.service`. Managed labels are
`org.nix-community.home.tern-{daemon,remote}-managed` on Darwin and
`tern-{daemon,remote}-managed.service` on Linux.

Stable profile wrapper paths keep ordinary executable/environment/socket changes
out of launchd plists; systemd uses `X-SwitchMethod=keep-old`. Changes take effect
on the next start rather than terminating running panes. Changing/removing
launchd supervisor policy, or disabling services, can still stop processes.
Plan those changes explicitly. Darwin logs live in private `daemon.log` /
`remote.log` files under the corresponding state directory; Linux uses the journal.

Upstream references: [keymaps](https://docs.stencil.so/tern/guides/commands.html),
[themes](https://docs.stencil.so/tern/guides/themes.html),
[settings API](https://docs.stencil.so/tern/reference/api-window.html#settings-cx).


## Kata

`aw1cks.modules.home.kata` is independent of Tern. Import this atom at the host's
composition root, then opt in with `services.kata.enable = true`. The public
`mbp` host does both; importing the Tern plugin does not enable the server.
The service does not manage the `tern-kata` worker, which remains under the
plugin's own opt-in supervision.

`packages.<system>.kata` packages Kata 0.23.0 from its hash-pinned dedicated
release source archive. Unlike the Git tag archive, it contains the production
web UI and vendored Go dependencies. The package identifies itself as
`nixpkgs`, so install-capable `kata update` commands cannot replace it. Use
`nix build .#kata` or `nix run .#kata -- version --json`; updates belong in
`modules/home/packages/_kata/package.nix`. Optional embeddings, remote backends
and additional services are not enabled implicitly.

The package carries `browser-auth.patch` for the pinned release: a configured
static token disables unauthenticated loopback browser-session bootstrap.
Loopback identifies a machine, not an OS user, so other local users must not
obtain an owner session without the private token. The web UI stays available
but requires explicit token login; native CLI and Tern clients are unchanged.
The patch and focused upstream policy regression must be reviewed when updating
Kata and can be removed only after equivalent upstream protection is verified.

### State, authentication and clients

`services.kata` exposes `package`, `stateDirectory`, `listenAddress`, `port` and
`autostart`. State defaults to `$XDG_STATE_HOME/kata` (`~/.local/state/kata`),
including the SQLite `kata.db`, native mutable `config.toml`, runtime records,
and `auth-token`. Relative paths, the Nix store and parent components are
rejected. This is not an automatic migration from an existing `~/.kata` home.

The runner creates private state (0700) and generates one random bearer token
(0600) atomically if absent. It reuses an existing private, owned regular token
file and refuses unsafe files without replacing them. Tokens and database data
never enter the Nix store; disabling the service preserves both.
Native clients authenticate using that file token. Browser login exchanges it
for a cookie plus session/CSRF credentials; anonymous local-session bootstrap
is disabled when the token is configured. No hosted account is required for
ordinary local issue creation. Do not put the token in shell history or Nix
configuration.

The default listener is `127.0.0.1:7777`; `listenAddress` accepts only
`127.0.0.1` or `::1`, and `port` must be a fixed positive TCP port. The runner
passes the listener explicitly and disables the embedded MCP server.

`_kata/connection.nix` defines one connection environment for the daemon and its
clients: `KATA_HOME`, the explicit SQLite `KATA_DSN`/`KATA_DB`,
`KATA_AUTH_TOKEN_FILE`, and a loopback `KATA_SERVER`. An inherited inline
`KATA_AUTH_TOKEN` is cleared so it cannot override the selected file.

The installed home-profile `kata` command binds these settings in its executable
launcher. When the service is enabled alongside Tern, the bundled `tern-kata`
helper does the same and includes the selected Kata package on PATH. Thus a new
client invocation does not depend on login-shell environment inheritance or a
previously started GUI/daemon seeing updated Home Manager session variables.
The module also exports the connection through session variables and Tern's
launcher/service environment for other clients. The generic `packages.kata`
output remains an unconfigured upstream CLI.

`KATA_SERVER` deliberately selects the managed endpoint instead of Kata's local
auto-start path. Clients fail when the service is stopped rather than spawning
an unmanaged daemon. Kata may describe this URL-selected connection as
\"remote\" even though it is loopback. It also takes precedence over workspace
server overrides; use an explicit named `--daemon` selection when intentionally
targeting another backend.

After activation, reopen existing Kata panes/client processes to use the new
profile launchers; they cannot repair the environment of an already-running
client. A routing-only client change does not require restarting the database
daemon. Native Tern login shells can use the real user's login environment,
so isolated smoke tests must use the generated client executables rather than
manually supplying the connection variables and masking an inheritance bug.

### Supervision and upgrades

The managed daemon runs `kata daemon start --foreground`, not Kata's detached
launcher. Its supervisor is `org.nix-community.home.kata-managed` on Darwin
and `kata-managed.service` under Linux's user manager. It starts at login by
default; `autostart = false` leaves it manually startable. Restart-on-failure
and a 45-second stop allowance preserve Kata's graceful shutdown. A concurrent
foreground daemon is rejected by Kata's ownership checks, not adopted or killed.
Retire any manually started daemon in the selected state directory before
enabling management.

Stable profile runner paths and systemd's `X-SwitchMethod=keep-old` avoid an
implicit database-owning process replacement on an ordinary rebuild. Package,
state or listener changes need a deliberate service restart. Changes to launchd
supervisor policy, or disabling the service, can still stop it. Darwin logs are
private `daemon.log` under the state directory; Linux uses the journal.
The browser-auth hardening also needs an explicit restart after rebuilding;
ordinary activation intentionally leaves a running old binary in place.
Restart discards process-local browser sessions, and new tabs require token
login. This auth-policy patch does not change the database schema.

Before upgrading or relocating an existing database: stop the service through
its user manager, back up the entire private state directory, rebuild, then
explicitly start it. Native startup may migrate the SQLite schema; an older
binary may not reopen it. Do not run detached `kata daemon start` alongside the
managed service. Disabling management does not delete or downgrade its state.
The package follows upstream's anonymous telemetry policy; native mutable Kata
configuration remains available for its documented preferences.

Upstream references: [packaging](https://github.com/kenn-io/kata/blob/v0.23.0/docs/development/packaging.md),
[configuration](https://github.com/kenn-io/kata/blob/v0.23.0/docs/reference/configuration.md),
[daemon selection](https://github.com/kenn-io/kata/blob/v0.23.0/docs/reference/daemon-discovery.md).
## Rust toolchains

`aw1cks.modules.home.rust` keeps rustup as the toolchain dispatcher, so
`rust-toolchain.toml`, `cargo +<toolchain>` and MSRV toolchains work unchanged.
It links Nix-built rust-overlay toolchains into rustup as custom toolchains
(`aw1cks.rust.toolchains`, by default `nix-stable` and `nix-nightly`) through
`home.file`. The Home Manager generation keeps them alive across garbage
collection. Activation makes `aw1cks.rust.defaultToolchain` the rustup default
only when none is set. rustup refuses channel names (`stable`, `nightly`,
versions) for custom toolchains, so those still download through rustup.
Linked toolchains cannot take `rustup component add` or `target add`: declare
extensions and targets in Nix instead.

On generic Linux, rustup is built without nixpkgs' toolchain-patching patch and
without its `LD_LIBRARY_PATH` wrapper. That patch rewrites each downloaded
toolchain's ELF interpreter, RUNPATH and `gcc-ld/ld.lld` to store paths that
nothing roots, so the toolchains break after a rustup upgrade plus GC
(NixOS/nixpkgs#473661). Upstream binaries run natively there. NixOS keeps the
patched rustup and its fragility; prefer the linked Nix toolchains there.

`modules/home/dev/_rust-toolchains.nix` is shared by the rust, language-server
and editor modules. Editors get one rust-analyzer from the Nix stable toolchain
and, with the rust module, rustup's proxies on their wrapper PATH. Every
compiler, Cargo, Clippy and rustfmt call then follows the project's toolchain
file, as in a shell.

## Shared Namespaces

The public reusable namespace in this repo is `aw1cks.*`.

The important parts are:

- `aw1cks.modules.<target>.*`: atomic reusable modules
- `aw1cks.profiles.<target>.*`: reusable bundles built from those modules
- `aw1cks.hostFacts`: normalized host metadata declared in `hosts/facts.nix`
- `aw1cks.identities`: named identity registry
- `aw1cks.identity.default` and `aw1cks.identity.selected`: default identity selection
- `aw1cks.roles`: constructor-owned role mapping

Downstream repos can keep using `aw1cks.*` as the shared upstream contract while adding their own local namespace for private modules and profiles.

Generic Home Manager networking belongs under `modules/home/networking/`.
The `aw1cks.modules.home.tailscale-serve` atom exposes the
`services.tailscale-serve.endpoints` registry without AI dependencies. Hosts
explicitly import and enable this networking owner; endpoint declarations do
not enable it. The registry is authoritative for the node's complete Serve
configuration; manual Serve entries are replaced rather than merged or preserved.
The Mac keeps this owner enabled with an empty registry so the next activation
clears retired endpoints rather than leaving persisted mappings behind.

The opt-in Darwin `aw1cks.modules.darwin.tailscale-app` atom retains the
Standalone app and applies declared client preferences at rebuild/login.
It does not replace the VPN, manage enrollment, or continuously enforce GUI
preferences. Serve remains independently authoritative.

## Identity Model

The current identity model is `aw1cks.identities`, not older `aw1cks.user.*` terminology.

`modules/schema/identity.nix` defines:

- `aw1cks.identities.<name>` entries with `fullName`, `email`, `username`, optional `homeDirectory`, and `authorizedKeys`
- `aw1cks.identity.default` as the default selected identity name
- `aw1cks.identity.selected` as the resolved default identity entry

Hosts can also opt into a specific identity with `hostFacts.identity`.

Constructor resolution is:

1. host-local constructor fields when explicitly set
2. matching values from `hostFacts`
3. selected identity values from `aw1cks.identities`
4. a platform-appropriate default home directory when needed

That means shared identity data can provide usernames and home directories without forcing every host root to repeat them.

## Host Facts

`hosts/facts.nix` declares `aw1cks.hostFacts` directly as a module option value.

Required fields per host:

```nix
{
  system = "...";
  kind = "nixos" | "darwin" | "home-manager";
  roles = [ ... ];
}
```

Optional shared metadata includes fields such as:

```nix
{
  identity = "...";
  user = "...";
  homeDirectory = "...";
  hostName = "...";
  tailnetHost = "my-host.example.ts.net"; # optional full Tailscale HTTPS hostname
  tags = [ ... ];
}
```

`tailnetHost` is machine metadata used by the opt-in Tailscale Serve and Darwin
Tailscale.app modules to check node identity. Hosts not using these modules do
not need it.

Facts are for safe shared metadata only.

Keep these out of facts:

- host-local `module` payloads
- embedded `home` payloads
- local file paths
- NVIDIA pin files
- secrets and `age.secrets.*` wiring

`hosts/default.nix` is the explicit repo-local host loader. It imports `hosts/facts.nix` and each `hosts/<name>/configuration.nix`, while host-local support files such as `hardware-configuration.nix`, `disko.nix`, `network.nix`, session modules, or repo-local provisioning helpers like `bootstrap-pre-kexec.sh` stay private to that host unless the relevant host root or provisioning wrapper consumes them deliberately.

## Constructors

The three host constructors are:

- `modules/constructors/nixos.nix`
- `modules/constructors/darwin.nix`
- `modules/constructors/home-manager.nix`

They all:

- resolve a matching facts entry
- assert the configured target kind and system
- inject `hostFacts` via `specialArgs` or `extraSpecialArgs`
- expand role-derived imports from `modules/roles/defaults.nix`
- add shared baseline imports from `modules/constructors/_lib.nix`

NixOS and darwin constructors also forward the same `hostFacts` through
`home-manager.extraSpecialArgs` into their embedded homes. Home Manager modules
therefore consume the same machine facts regardless of deployment mode.

The shared helper file `modules/constructors/_lib.nix` is intentionally small. It centralizes repeated constructor policy such as facts lookup, role expansion, target assertions, baseline imports, and user/home resolution.

Constructors also own package-set creation. The shared helper now builds a configured `pkgs` instance per target so NixOS, nix-darwin, and standalone Home Manager all see the same baseline behavior for `allowUnfree`, NVIDIA license acceptance, `pkgs.unstable`, and `pkgs.llm-agents`. The old shared `modules/shared/nixpkgs.nix` path no longer injects overlays or `nixpkgs.config`; it remains only as a compatibility marker module for existing imports.

For NixOS specifically, the constructor uses `inputs.nixpkgs.nixosModules.readOnlyPkgs` and provides `nixpkgs.pkgs` directly. That keeps the configured package set authoritative in one place and avoids mixing constructor-owned `pkgs` with module-side `nixpkgs.config`.

The shared primary-user realization for NixOS lives in `modules/nixos/user/default.nix`. The NixOS constructor resolves identity, username, and home directory first, then passes those resolved values into that reusable module.

## Role Expansion

Roles are labels in `hostFacts.roles`.

Constructors do not interpret those labels ad hoc. They consult the central mapping in `modules/roles/defaults.nix`, which maps roles onto reusable profiles per target.

The stable contract is:

- hosts declare roles once in `hosts/facts.nix`
- constructors expand those roles before host-local modules
- host-local modules still override through normal module ordering

The exact current role inventory may change. Treat `modules/roles/defaults.nix` as authoritative for the live mapping.

Unknown role names fail constructor assertions during evaluation.

## Host Configuration Shapes

`configurations.home` is for standalone Home Manager hosts.

- attr names must follow `user@host` or `user@host.domain`
- the `user` segment must match the resolved constructor user
- `nvidia.enable` and `nvidia.pinFile` provide the shared standalone Linux NVIDIA contract
- Linux hosts get `targets.genericLinux.enable` plus `/nix/var/nix/profiles/default/bin` on `home.sessionPath`, because the `nix.sh` that `genericLinux` sources only exports the per-user profile and leaves a daemon-installed Nix or Lix client off `PATH`
- Generic Linux homes default `systemd.user.systemctlPath` to `/usr/bin/systemctl` with `lib.mkDefault`. The distro client can fall back to the user D-Bus connection when the private systemd socket is stale or refuses connections; hosts can override the path normally.

`configurations.nixos` is for NixOS systems.

- hosts can provide an optional embedded `home` payload
- when present, the constructor imports the Home Manager NixOS module through `aw1cks.modules.nixos-home-manager.default`
- the shared primary-user module imports `aw1cks.modules.nixos.user-shell-policy`, and profiles can set `aw1cks.user.shellPolicy` to choose the resolved login shell centrally

Current thin reusable NixOS bundles follow the same split used elsewhere in the repo: profiles stay small and import reusable atoms. For example, `aw1cks.profiles.nixos.server` now imports a shared `aw1cks.modules.nixos.server-security` baseline rather than carrying SSH policy inline.

Because `aw1cks.modules.*` and `aw1cks.profiles.*` are exported as deferred modules, any config that depends on `pkgs` must live inside a real module function such as `{ pkgs, ... }: { ... }` so it is evaluated in the target module system rather than in the outer flake-module context.

The current shared NixOS atom surface now includes reusable entries for boot, kernel selection, EFI/systemd-boot, network baseline, PipeWire audio, Wayland environment defaults, shared user realization, shell policy, and server security. Host roots should compose those atoms through profiles or direct imports rather than reintroducing ad hoc copies.

Host-local compositor and shell choices remain separate from that shared baseline. The current `desktop` host keeps its small `niri` wrapper under `hosts/desktop/niri.nix`, layers `noctalia-shell` through a host-local embedded Home Manager import in `hosts/desktop/noctalia-home.nix`, and intentionally keeps both concerns repo-local instead of promoting a reusable desktop-shell abstraction yet.

Host-local storage ownership stays under `hosts/<name>/disko.nix`, with the shared `disko` input imported centrally by the NixOS constructor path so repo-local hosts can opt into disk layout definitions without widening the reusable module surface.

Provisioning-specific bootstrap access stays repo-local rather than expanding the `aw1cks.*` reusable contract. The current installer bootstrap SSH path is exposed as `flake.nixosModules.installer-bootstrap-ssh`, which is intended for installer or kexec environments and not for final host imports.

`configurations.darwin` is for nix-darwin systems.

- hosts can provide an optional embedded `home` payload
- the constructor derives `system.primaryUser`, `users.users.<name>.home`, and Home Manager username/home-directory defaults from resolved identity data

The Darwin desktop profile imports `aw1cks.modules.darwin.chatgpt-desktop` and
enables the official ChatGPT desktop app through Homebrew's `chatgpt` cask by
default. Downstream consumers can disable it in their nix-darwin host module
without `lib.mkForce`:

```nix
configurations.darwin.work-mac.module = {
  modules.ai.chatgpt.enable = false;
};
```

The atomic module defaults to disabled when imported without the desktop
profile. To opt in independently, import
`config.aw1cks.modules.darwin.chatgpt-desktop` and set
`modules.ai.chatgpt.enable = true;` in the nix-darwin module. This enables
Homebrew management; Homebrew itself must already be installed. This feature
does not install an unofficial Linux client.

The option uses the same `modules.ai` namespace as the Home Manager AI tools,
but belongs to the nix-darwin module system: setting it inside a Home Manager
configuration does not control system-wide Homebrew management. The desktop
profile owns the GUI app default, independently of the developer AI profile
and its OMP model-tier settings.

Disabling removes the cask from the managed Brewfile. The desktop profile's
existing `homebrew.onActivation.cleanup = "zap"` policy can uninstall it and
remove application data on the next activation.

The shared Home Manager `multimedia-apps` module disables mpv's horizontal
swipe/wheel seeking on macOS through `programs.mpv.bindings`. Vertical volume
scrolling and keyboard controls remain enabled; Linux bindings are unchanged.

## Validation

Validation is intentionally narrower than a full switch or deployment.

See [`docs/validation.md`](./validation.md) for the current `nix flake check` coverage and its limits.
