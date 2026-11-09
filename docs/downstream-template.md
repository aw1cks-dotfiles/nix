# Downstream Template

This repo ships `templates.default` as a starter downstream flake that layers private configuration on top of the shared `aw1cks.*` interface.

The authoritative template files live under `templates/default/`.

The template is reference material, not a turnkey downstream repo. Several example host facts and host declarations stay commented out until a real downstream consumer fills them in.

## Purpose

Use the template when you want a downstream repo to:

- consume this repo as a reusable library
- keep organization-specific modules and profiles private
- preserve the shared upstream contract instead of copying constructor wiring by hand

## Flake-File Contract

The downstream template's `modules/flake-file.nix` imports:

- `inputs.flake-file.flakeModules.default`
- `inputs.dendritic-lib.flakeModules.downstream-flake-file`

That means the public library's reusable transitive flake inputs come from this repo's exported contract in `modules/_internal/flake-file-inputs/default.nix`.

Downstream repos should treat that exported module as authoritative unless they are intentionally overriding part of the contract.

## Canonical Commands

Downstream consumers inherit `nix run .#rebuild` and its default-app alias
`nix run .`, `nix run .#update -- [inputs...]`, and
`nix run .#clean -- [days]`. Update forwards input names and flags to
`nix flake update` (except `--flake`) and regenerates the
flake at the repository root, then fetches all input sources into the local
store. Update uses best-effort GitHub authentication; rebuild does not inject
credentials into NH. Cold-store rebuilds may still hit rate limits.
Clean defaults to 7 days; use
`nix run .#clean -- --gc-only [days]` for garbage collection only or
`nix run .#clean -- --optimise-only` for store optimisation only.

Update operates on the enclosing checkout. For a selective upgrade use
`nix run .#update -- nixpkgs`; for local integration testing use ordinary CLI
overrides such as `nix flake check --override-input dendritic-lib path:/path/to/library`.

Neither the library nor the template ships a justfile, so there is nothing to keep
in sync and no wrapper recipe to drift from the apps. Consumers that want
`just`-style shortcuts can add their own thin aliases over the apps.

Initial cache setup and break-glass recovery deliberately bypass apps. The
template does **not** bundle `modules/integrations/_cache-bootstrap/bootstrap.py`.
Use a reviewed library source checkout and run from that checkout:

```sh
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py bootstrap standalone-hm '/path/to/consumer#user@host'
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py --recovery bootstrap standalone-hm '/path/to/consumer#user@host'
```

Select the actual owner (`nixos`, `darwin`, or `standalone-hm`) and output name.
These source commands can repair cache policy when the flake cannot evaluate;
activation still requires a working target flake afterward. Run them from the
library checkout; no recipe or wrapper supplies that path.
See [cache bootstrap](./cache-bootstrap.md).


## Layering Model

The template demonstrates a simple split:

- `aw1cks.*` stays the shared upstream namespace
- a downstream-local namespace such as `org.*` holds private modules, profiles, and options
- `hosts/facts.nix` provides downstream host metadata
- `hosts/default.nix` is the explicit downstream host loader
- host configuration roots import downstream profiles and local modules as needed

This keeps shared library concerns reusable while giving the downstream repo room for private certificates, private git settings, internal package sources, and site-specific policies.

## WezTerm configuration

The shared WezTerm module lets Home Manager generate `wezterm.lua`; it no longer
overrides that file with an explicit `.source` that discards
`programs.wezterm.extraConfig`. Shared Lua lives in `defaults.lua`,
`appearance.lua`, `binds.lua`, and generated `settings.lua`.

Configuration precedence is shared defaults → `programs.wezterm.settings` →
`programs.wezterm.extraConfig` → optional `wezterm/user.lua`.
Native settings and returned Lua tables use shallow overrides: assigning `keys`
replaces the entire shared key list. To append bindings, mutate the shared
`config.keys` in `extraConfig`; `wezterm` and `config` are already in scope:

```nix
{
  programs.wezterm.extraConfig = ''
    table.insert(config.keys, {
      key = "Enter",
      mods = "SHIFT",
      action = wezterm.action.SendString("\x1b\r"),
    })
  '';
}
```

This opt-in Shift+Enter convention sends ESC CR for applications that support it;
it is not a universal terminal newline protocol. A `return { ... }` is optional.
Ordinary Lua fragments, including `lib.mkBefore`/`lib.mkAfter` contributions,
run inside the shared extension callback. `lib.mkForce` on `extraConfig` instead
replaces the complete entrypoint, opting out of shared configuration.

The existing `xdg.configFile."wezterm/user.lua".source` hook remains supported:
return a table with `apply(config, settings)`. An absent hook is ignored; syntax,
dependency, invalid-interface, and apply errors fail configuration loading.
Do not fork the entrypoint to extend it.

Tab selection uses physical number-row keys: Ctrl+Shift+1–8 select those tabs,
and Ctrl+Shift+9 selects the last tab. Cmd+1–9 has the same physical behavior on
macOS. Pane-split bracket keys and Shift+T tab creation also use physical US-key
positions, without globally changing character-based editing shortcuts.
This handles British Shift+2 (`"`) and Shift+3 (`£`) as well as other layouts.

When adopting this change downstream, update the `dendritic-lib` input first.
Remove layout-specific tab-binding patches; move application-specific bindings
such as Shift+Enter to native `extraConfig` if desired. Once migrated off
`user.lua`, remove its installation and any source-text hook assertion: scanning
the old entrypoint is not a stable capability check.


## Shared agent skills

The shared Home Manager AI module exposes a read-only `modules.ai.skillsSource`: a flat directory of complete, selected skill directories for compatible agent harnesses.
When `programs.omp.enable` is true, the module appends this output to `programs.omp.settings.skills.customDirectories`.
OMP discovers these skills alongside native user/project skills; the module does not own or replace `~/.omp/agent/skills`.
Caller-provided custom directories remain in the list. An explicit `lib.mkForce` on `customDirectories` overrides the normal composition.
Other harnesses can consume the same `skillsSource` output independently.

The default selection includes bundled skills and the curated collections from four public non-flake inputs.
The library records their revisions and content hashes in its own `flake.lock` and exports those exact revisions as downstream input URL defaults:

- `intel-performance-skills`: [Intel performance skills](https://github.com/intel/intel-performance-skills), exposed as `intel/<name>`; retained rather than also importing duplicate copies from Intel's broader hub
- `low-level-dev-skills`: [low-level development skills](https://github.com/mohitmishra786/low-level-dev-skills), exposed as `lowlevel/<name>`
- `rewrite-rs-skills`: [Rust engineering skills](https://github.com/rewrite-rs/skills), exposed as `rewrite/<name>`
- `trailofbits-skills`: [security and testing skills](https://github.com/trailofbits/skills), exposed as `trailofbits/<name>`
- Bundled skills, including `context7`, `git-workflow`, and `git-history-hygiene`, use `builtin/<name>`; namespace prefixes are selectors, not installed directory names

`modules/home/dev/_skills-policy.nix` is the explicit reviewed inventory for low-level, rewrite-rs, and Trail of Bits skills.
New upstream siblings do not enter those collections automatically; a missing reviewed path fails evaluation rather than silently reducing coverage.
The retained low-level inventory covers specialist compiler/build/debugger, binary, architecture, allocator, kernel, I/O, eBPF, runtime, and virtualization workflows.
Intel owns the installed `linux-perf` name.

The selective cutover replaces `lowlevel/rust-ffi` with `rewrite/rust-ffi`; migrate exact selectors to the new ID.
Rewrite-rs also supplies ownership, API/error/type design, async correctness, concurrency, performance, documentation, observability, testing, and dependency-security guidance.
Specialist Rust compiler/Cargo, cross/no-std, debugger/profiler, unsafe/Miri, and async-internals material remains in low-level.
Trail of Bits supplies `aflpp` and `cargo-fuzz`; generic low-level fuzzing remains because these do not replace its libFuzzer/harness coverage.

Known-error guides are not imported: rewrite-rs `unsafe-rust` incorrectly describes zero as an invalid boolean representation, and Trail of Bits `address-sanitizer` incorrectly recommends skipping macOS.
The reviewed Trail of Bits `libfuzzer`, `harness-writing`, and `coverage-analysis` guides also remain deferred for correctness issues.
Full `c-review` and `rust-review` plugins are not flattened into skill directories: they need sibling plugin assets and harness-specific orchestration tools.
This cutover retains the three existing low-level correctness patches rather than dropping uncovered specialist skills to remove patch maintenance.

```nix
{
  modules.ai.skills = {
    select = [
      "-lowlevel/cmake"
      "-rewrite/rust-docs"
    ];
    extra."local/team-workflow" = ./skills/team-workflow;
    # To replace a bundled skill entirely:
    # extra."builtin/context7" = ./skills/context7;
  };
}
```

Normal module definitions of `select` concatenate with the ordinary curated default selection (`builtin/*`, `intel/*`, `lowlevel/*`, `rewrite/*`, and `trailofbits/*`).
Use `lib.mkForce []` to clear those selections; explicit `extra` entries remain included unless excluded separately.
Each selector is an exact `namespace/name` or contains at most one `*` per component; `*` never crosses `/`.
All includes and `extra` IDs are unioned, then all `-` exclusions are subtracted regardless of module order.
An unknown include fails evaluation; an exclusion matching nothing warns, so removed upstream skills do not break downstream exclusions.
Exclusions govern this output only, not a consumer's independently installed skills.

`extra` is an attribute set of paths keyed by ID.
A matching ID replaces the entire bundled directory, including its patch and licence metadata: files from different versions are never merged.
Conflicting ordinary definitions of the same `extra` ID fail through normal Nix option merging; use a per-key `lib.mkForce` for an intentional override.
Two selected IDs with the same installed basename fail instead of silently overwriting one another.
`SKILL.md` frontmatter must be valid YAML and its `name` must equal that basename.
Consumers that previously assigned `skillsSource` must migrate to `select` and `extra`; it can no longer bypass composition.

Assembly copies references, scripts, executable permissions, and upstream root licence notices into `.upstream-license` within each downloaded skill directory.
It does not execute upstream scripts.
Three local patches correct coroutine move ownership, io_uring provided-buffer setup/SQE selection, and unsafe kernel debugger entry guidance.
They apply during assembly, not evaluation; a patch that no longer applies blocks the build and must be reviewed when updating the input.
No patched derivation is read during evaluation.

The shared input declarations automatically generate downstream `follows` entries.
The downstream export projects the skill revisions from the library checkout's `flake.lock` into revision-pinned URLs; downstreams do not need to copy that lockfile.
Their own lockfile records the resolved sources, and `dendritic-lib` follows those top-level inputs.
The library's root URLs remain floating so Renovate can continue updating its lockfile.

Adopt reviewed skill updates downstream with `nix run .#update -- dendritic-lib`.
This updates the library, regenerates downstream `flake.nix` with its skill revisions, and archives the inputs, refreshing the downstream lock as needed.
For manual adoption, update `dendritic-lib`, run `nix run .#write-flake`, then run `nix flake lock`.
Updating only downstream skill lock nodes cannot advance revision-pinned URLs.
A fork, revision, or local source can still be selected explicitly through `flake-file.inputs.<name>.url`; ordinary caller definitions override the shared pinned defaults.
Such overrides are intentional departures from the library's reviewed versions, not independently approved content.

In the library repo, Renovate can automerge skill updates and weekly mixed lockfile maintenance only after CI passes.
The required `skill-input-review` status compares all four effective locked `narHash` values with the protected target branch's `flake.lock`.
For changed contents, the default-branch reporter posts one concise comment with approval guidance, upstream two-SHA diff links, and a complete exact two-tree diff artifact.
A content change waits for an authorized human's GitHub **Approve** review on the current PR head, including when it arrives through mixed lockfile maintenance.
An unrelated update, or a revision change with identical contents, requires neither approval nor a comment. Reverting content changes removes the reporter's previous review comments.
Host builds wait before Nix installation; review events automatically rerun the read-only gate and host checks after approval.
A new push/rebase requires fresh approval; dismissal and superseding reviews are re-evaluated.
Bot reviews, PR-author reviews, comment text, labels, and checkboxes do not authorize changed contents.
The flake check uses `--no-update-lock-file`, so Nix cannot replace checked inputs while resolving a stale lock.

The target branch and GitHub review history replace the independently maintained approval-hash ledger.
`.github/skill-inputs.json` now inventories source identities and supplies the unchanged set of downstream skill defaults.
Required-check setup and the automerge-safe rollout are documented in [validation.md](validation.md#required-check-rollout).
Passing assembly checks does not establish instruction safety; review the upstream diff rather than approving blindly.
This GitHub approval gate is not inherited by importing Nix modules; downstream pinning supplies reviewed defaults, not runtime enforcement against explicit overrides.
`platformAutomerge: false` makes Renovate itself observe green CI before merging.

This is repository CI policy, not a runtime restriction on consumer forks or local input overrides.
Independent consumers need an equivalent CI gate or must retain manual merge review; this workflow and its GitHub approval history are not inherited through a flake input.
OMP loading is wired by this module; loading in other harnesses and consumer-specific precedence remain the consumer's responsibility.

## AI Model Routing

The shared Home Manager AI module exposes model tiers under `modules.ai.models` so downstream hosts can replace models without copying the OMP agent map:

```nix
{
  modules.ai.models = {
    frontier = "anthropic/claude-opus-4-6:high";
    small = "ollama/qwen3-coder";
  };
}
```

The available tiers are `frontier`, `premium`, `standard`, and `small`. Each value is an OMP model selector, including an optional `:thinking` suffix.

The default inventory uses models available through ChatGPT/Codex subscription sign-in:

| Tier | Model | Reasoning effort |
| --- | --- | --- |
| `frontier` | GPT-6 Astra | `xhigh` |
| `premium` | GPT-6.1 Sol | `high` |
| `standard` | GPT-6.1 Sol | `medium` |
| `small` | GPT-6 Luna | `low` |

Premium and standard share the current Sol model, with lighter reasoning for general delegated work. Frontier prioritizes planning and review quality; small prioritizes latency and subscription efficiency. OMP uses explicit reasoning levels, and the frontier default does not require an API-only Pro model.

These choices follow the [Codex model recommendations](https://developers.openai.com/codex/models) and [model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection). Availability still depends on the signed-in account, client, and workspace permissions.

These tier values feed the shared default model-role assignments. A downstream module can still override an individual assignment directly through `modules.ai.omp.settings.modelRoles.*`; those explicit settings take precedence over the shared defaults.

Shared OMP defaults (theme, status line, approval mode, onboarding markers, task isolation/delegation guards, and bash-interception safety policy) are declared per-key with `lib.mkDefault` under `modules.ai.omp.settings`, so a downstream `settings` attrset merges key-by-key instead of replacing the shared block. Downstream modules only declare the deltas — typically model routing and provider policy. Nested defaults are per-subkey (`task.maxRecursionDepth`, `task.agentModelOverrides`) for the same reason: a downstream `task.isolation.*` assignment merges with, rather than replaces, the shared delegation guard.

Compound Bash commands are enabled by default with `bash.allowCompoundCommands = true`.
OMP evaluates literal `&&` chains per command; unmatched commands still use the normal Bash approval policy and mode.
Set `modules.ai.omp.settings.bash.allowCompoundCommands = false` to opt out.

### Oxocarbon themes

The shared AI module installs `~/.omp/agent/themes/oxocarbon-dark.json` when OMP is enabled and defaults `modules.ai.omp.settings.theme.dark` to `oxocarbon-dark`.
The JSON palette is adapted from [Oxocarbon.nvim](https://github.com/nyoom-engineering/oxocarbon.nvim); OMP does not change the terminal's background, so use `#161616` in the terminal for a matching canvas.
Downstream configurations can override the dark theme through the existing per-key settings interface; the light-theme slot is unchanged.

The shared CLI tools module supplies the checked-in `oxocarbon-dark.tmTheme` through `programs.bat.themes.oxocarbon-dark.src`, registers the companion syntax overrides (`Go`, `JSON`, `Python`, `Rust`) through `programs.bat.syntaxes`, and selects the theme with `programs.bat.config.theme`.
Home Manager installs the theme and syntax files and rebuilds bat's cache during activation; no manual `bat cache --build` step is needed after switching.
The sources of truth live under `modules/home/shells/files/bat/`, not mutable files under `~/.config/bat`.

Delta uses the same compiled `bat` theme and syntax cache: `modules/home/vcs/default.nix` declares a `delta "oxocarbon"` feature with `syntax-theme = "oxocarbon-dark"` and selects it via `programs.delta.options.features`.
Difftastic (`difft`) only emits 16-color ANSI escapes, so `modules/home/vcs/default.nix` sets `programs.difftastic.options.background = "dark"` and `DFT_BACKGROUND = "dark"`, while WezTerm, OMP, and Neovim `:terminal` align their 16-color ANSI slots to Oxocarbon (`#ee5396` red, `#42be65` green, `#ffe97b` yellow, `#33b1ff` blue, `#ff7eb6` magenta, `#3ddbd9` cyan).

After switching, check `bat --list-themes` for `oxocarbon-dark` and launch OMP normally to use its declared dark-theme default.

## Declarative Private Tailscale Serve

The reusable Home Manager export is
`config.aw1cks.modules.home.tailscale-serve`. Its public interface is
`services.tailscale-serve`, independent of the AI module.
For example, a **flake-parts host composition** can expose an HTTP service
without importing any AI configuration:

```nix
{ config, ... }:
{
  configurations.home."alex@server".module = {
    imports = [ config.aw1cks.modules.home.tailscale-serve ];
    services.tailscale-serve = {
      enable = true;
      endpoints.notes = {
        httpsPort = 10443;
        targetPort = 3000;
      };
    };
  };
}
```

The matching host facts must supply `tailnetHost`. Endpoints proxy private
HTTPS roots to HTTP on `127.0.0.1`; the backend service has its own lifecycle.
Endpoint names are Nix composition keys. Different modules contribute entries
to this registry; set an entry's `enable = false` to omit it without stopping its
backend. Enabled entries must have distinct HTTPS ports.
The interface intentionally does not expose public Funnel, raw TCP, or path
routing options.

Import this networking export explicitly in the host's Home Manager composition;
the AI module does not import it or register endpoints. Registering endpoints
does not enable publication: `services.tailscale-serve.enable` remains a separate
opt-in. On `mbp`, the host explicitly imports this owner and keeps it enabled
with an empty endpoint registry. The next activation applies an empty Serve
configuration to remove retired endpoints, including any persisted public
Funnel mappings; removing service declarations alone does not clear live state.
No live services or Serve state are changed merely by editing this repository.

The existing Tailscale.app daemon is retained on macOS; Linux uses the pinned
CLI and requires an already-running daemon plus user operator authorization.
`services.tailscale-serve.executable` selects the absolute CLI path.
On macOS, `org.nix-community.home.tailscale-serve` runs at login and every
60 seconds, logging to `~/.tailscale-serve.log`. On Linux,
`tailscale-serve.timer` invokes a oneshot user service on startup and every
60 seconds after completion. Run `tailscale-serve-managed` to apply the
installed declaration immediately.

### What Is Actually Declarative?

Nix renders the **complete raw Serve configuration** from the enabled endpoint
registry. The managed job reads live state only to skip an already-matching
configuration, then applies the whole JSON through `tailscale serve set-raw`.
There is no arbitrary-state merge, per-route ownership journal, adoption logic
or protection for manually added mappings.

**Nix is the sole source of truth while this module is enabled.** Undeclared
ports, paths, foreground handlers, TCP forwards, Tailscale Services handlers and
Funnel configuration are removed. Changed manual values are overwritten, not
preserved or rejected as ownership conflicts. Do not run another Serve manager
against the same node. This controls Serve, not Tailscale login, DNS, ACLs or
account policy.

Normally this is one configuration replacement, without reset/re-add churn.
Tailscale cannot directly convert an existing HTTP/TCP listener or foreground
listener into background HTTPS on the same port. For that case, the helper
first applies the desired configuration without the incompatible ports, then
the complete desired configuration. Both states come only from Nix; no manual
state is merged. Unchanged declared ports remain configured. If a write fails,
the next scheduled apply converges from the resulting live state.

### Apply Capability And Lifecycle

`serve set-raw` is an **undocumented CLI capability**, verified with Tailscale
1.104.4. It accepts raw `ipn.ServeConfig` JSON on stdin and calls the native
whole-configuration API
([source](https://github.com/tailscale/tailscale/blob/v1.104.4/cmd/tailscale/cli/serve_v2.go#L379-L390)).
The helper fails clearly if this capability is unavailable; it does not fall
back to `serve reset` or a best-effort series of per-route changes. Tailscale.app
does not discover the generated file itself: the managed apply step loads it.

One private lifecycle marker remains at
`~/.local/state/tailscale-serve/managed.json` under the configured XDG state
directory. It contains only a version and the expected node hostname, **not
routes or a snapshot of Serve state**. It distinguishes never-enabled homes
from a managed activation and allows failed disable cleanup to be retried.
The old `stateDirectory` option and ownership-journal machinery are removed.

An empty enabled registry applies `{}` and clears Serve. Disabling the module
and switching stops any loaded controller first, applies `{}` if its activation
marker exists, and removes the marker only after successful cleanup. A
never-enabled home does not clear an existing manual configuration. If
Tailscale is offline or the active node identity differs, cleanup fails visibly
and retains the marker; restore the intended identity/operator access and
repeat activation. Dry runs do not stop jobs or change Serve.

Stopping only the periodic job does **not** clear persisted Serve state.
Before removing the networking module/profile entirely or changing node/XDG
state identity, disable and switch once while cleanup is still available.
Identity is checked around reads and before writes; separate CLI calls cannot
make an external profile switch atomic.

Tailscale login, HTTPS certificate enablement and access rules remain
administrative prerequisites. The helper never elevates privileges or changes
account policy. Inspect the installed configuration with
`/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status`.

`packages.tailscale-serve-reconcile` exposes the apply helper with a settings
JSON argument. `checks.<system>.tailscale-serve` covers private desired state,
identity guards, idempotence, marker persistence and disable cleanup. Historical
live Mac checks exercised removal of undeclared ports/paths, addition/removal
of declared HTTPS endpoints, and HTTP/TCP/foreground-to-HTTPS transitions while
retaining unchanged mappings. These observations describe the generic owner,
not the current empty registry or its pending cleanup. Full clear-on-disable
is unit-tested, not exercised against live state. Linux lifecycle is evaluated,
not deployed here.

### Community Approaches And Why This Adapter Remains

The pinned nixpkgs
[NixOS `services.tailscale.serve` module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/tailscale-serve.nix)
also renders JSON and uses a systemd apply step:
`tailscale serve set-config --all`. It targets
[Tailscale Services configuration](https://tailscale.com/docs/reference/tailscale-services-configuration-file),
not these existing per-device HTTPS roots, and the configuration-file API has
a [documented frontend TLS limitation](https://github.com/NixOS/nixpkgs/issues/530174).
That issue also documents CLI-driven oneshot units as a workaround.

[tsnsrv](https://github.com/boinkor-net/tsnsrv) provides a generic NixOS service
registry too, but each proxy joins as its own tailnet participant with separate
identity/state and enrollment credentials. That is useful for service-specific
hostnames, but changes the node identity and topology.

Here, the generic Home Manager registry renders authoritative whole-Serve JSON
and uses the existing Mac app's raw apply path. It retains the existing node
identity for private HTTPS endpoints, but intentionally does not preserve undeclared
Serve configuration. It is not a drop-in alias for the upstream NixOS option,
and does not claim to configure the entire Tailscale daemon declaratively.

## Declarative Tailscale.app Preferences on Darwin

Keep the Standalone Tailscale.app for its GUI, exit-node client support and
macOS VPN integration. The opt-in Darwin atom
`config.aw1cks.modules.darwin.tailscale-app` configures that existing app; it
does not install a second daemon or migrate node identity:

```nix
{ config, ... }:
{
  configurations.darwin.mbp.module = {
    imports = [ config.aw1cks.modules.darwin.tailscale-app ];
    services.tailscale-app.enable = true;
  };
}
```

The desktop Homebrew configuration already installs `tailscale-app`. Other
consumers must install the Standalone app themselves. The machine facts must
provide matching `hostName` and `tailnetHost`; the node name is not repeated in
the host composition. Only `mbp` enables this preference module here.

`services.tailscale-app` declares `acceptDNS` and `acceptRoutes` (both default
true), `shieldsUp` (false), `autoUpdate` (false), `checkForUpdates` (true) and
`startOnLogin` (true). nix-darwin writes the documented Standalone app defaults
for login startup and Sparkle updates in the primary user's preferences. A
user-scoped `tailscale-app-preferences` command applies the hostname, DNS,
routes, shields and update flags through the app's bundled `tailscale set`.
It refuses to modify an active profile outside the fact-derived tailnet.

The command runs after a rebuild and through the
`org.nixos.tailscale-app-preferences` LaunchAgent at GUI login, waiting up to
one minute for the backend to become Running. There is no periodic preference
enforcement. Inspect `~/.tailscale-app-preferences.log` for login failures, or
run `tailscale-app-preferences` explicitly after resolving them. A rebuild
without a GUI session defers CLI preference application until login.

On a fresh machine, launch Tailscale.app, approve its system extension/VPN
configuration and sign in before expecting the preference command to succeed.
Authentication and persistent node identity remain app-managed outside the
Nix store; this module creates no enrollment keys or MDM profiles. Some
documented app policies are plan-dependent or may require an app restart;
ordinary defaults are not an MDM-enforced lock. See the upstream
[macOS preference instructions](https://tailscale.com/docs/integrations/mdm/mac).

Only the declared client preferences converge. Exit-node selection,
authentication, advertised routes and account policy remain untouched. GUI
changes to managed settings can persist until the next apply. Disabling the
module stops reapplication; it does not log out, reset preferences or delete
app state. Disable and switch once before removing the module import entirely.
The Homebrew app itself is not version-pinned by Nix.

This is separate from the authoritative whole-Serve owner above: retaining
interactive app settings never preserves undeclared Serve mappings. Do not
enable the native `services.tailscale` daemon alongside this module.

Verification exercised the real app CLI preference apply, a generated login
agent exiting successfully, and the generated disabled-state cleanup unloading
that agent and removing its plist. A helper built for another tailnet refused
to apply and preserved the live preferences. GUI controls, login after an actual
logout/reboot, and selecting a live exit node were not exercised.

## Zed Kubernetes And CRD Schemas

`inputs.dendritic-lib.flakeModules.default` provides `config.aw1cks.modules.home.zed`
in the flake-module configuration. Downstream Home Manager compositions inherit
its tooling/options only if they import that feature directly or through a profile;
adding the input alone does not enable Zed. There is no `flake.modules` output.

Public CRD schemas come from the shared **`crds-catalog` non-flake input**. The
`downstream-flake-file` contract declares it and automatically generates
`dendritic-lib.inputs.crds-catalog.follows = "crds-catalog"`. After adopting this
library change, regenerate the downstream flake with `nix run .#write-flake` and
lock the new input. Update it independently with `nix flake update crds-catalog`.

To select a different revision, add this to the downstream **flake-parts module**
that configures `flake-file` (replace the illustrative revision):

```nix
{
  flake-file.inputs.crds-catalog.url = "github:datreeio/CRDs-catalog/<revision>";
}
```

A catalog fork or local snapshot can also be used if it preserves the selected
`<group>/<kind>_<version>.json` paths. Regenerate with `nix run .#write-flake` after
changing the URL. Consumers managing `flake.nix` directly must declare
`inputs.crds-catalog` with `flake = false` and the matching
`inputs.dendritic-lib.inputs.crds-catalog.follows = "crds-catalog"` themselves.
The curated public selection is unchanged by an input override: use `extraCRDs`
for additional operators or release-accurate CRD overrides rather than expecting
all catalog entries to be imported.

With the feature imported, add a downstream **Home Manager module**, not flake settings:

```nix
{ ... }:
{
  aw1cks.zed.kubernetes = {
    extraCRDs = [ ./crds/platform.yaml ];
    manifestGlobs = [ "**/platform/resources/**/*.yaml" ];
  };
}
```

The paths are illustrative downstream locations, not files supplied here; the CRD
path is relative to this Home Manager module. `extraCRDs` accepts raw
`apiextensions.k8s.io/v1` CRD YAML/JSON, multi-document files, and `List` wrappers;
only served versions are compiled. Both lists merge additively with shared config.
Use `lib.mkForce` (adding `lib` to the module arguments) to replace `manifestGlobs`
intentionally. No raw Zed schema settings replacement is needed.

Downstream CRDs for installed operator releases override matching public
group/version/kind schemas; duplicate GVKs among extras fail. The read-only
`aw1cks.zed.kubernetes.schemaPackage` exposes `bundle.json`, `inventory.json`, and
`kubeconform/` for YAML LS, Helm, and kubeconform, with no unknown-GVK remote fallback.

Definitions must use self-contained references; nonlocal references are rejected.
Private CRDs enter the world-readable Nix store and potentially binary caches:
include **definitions only**, never instances or credentials. See
[Zed schema policy and validation limits](./zed-parity.md#yaml-kubernetes-and-helm-schemas)
for pinned coverage, strictness, network caveats, and checks not performed.

## Identity Use In The Template

The template extends `aw1cks.identities` with a downstream-specific identity example in `templates/default/modules/org/meta.nix`.

That example now also shows where to place public SSH authorized keys for the shared identity contract used by NixOS hosts.

Hosts can then select that identity through `hostFacts.identity`, or the downstream repo can change `aw1cks.identity.default` if that should become the default everywhere.

## What The Template Includes

- a downstream `flake-file` source in `templates/default/modules/flake-file.nix`
- an explicit host loader in `templates/default/hosts/default.nix`
- example host facts in `templates/default/hosts/facts.nix`
- example host declarations in `templates/default/hosts/examples.nix`
- an example private namespace in `templates/default/modules/org/`
- a generated top-level `templates/default/flake.nix`

## What It Does Not Include

The template does not ship a canonical downstream secrets inventory.

It also does not ship a ready-to-evaluate example host by default; consumers are expected to uncomment or replace the example host data before using it as a real flake.

If a downstream repo adds one, keep it separate from facts and composition roots. See [`docs/secret-management.md`](./secret-management.md) for boundary guidance.

## Typical Workflow

1. Start from `templates.default`.
2. Rename the example downstream namespace if needed.
3. Replace the example identities, domains, and certificate paths.
4. Uncomment and adapt the example host facts and host declarations.
5. Regenerate the generated flake with `nix run .#write-flake` after editing the downstream `modules/flake-file.nix`.
6. For normal operation, use `nix run .#rebuild`, `nix run .#update -- [inputs...]`, and `nix run .#clean -- [days]`; `nix run .` is the default rebuild alias. For first activation or recovery, follow the source-checkout procedure above instead of requiring an app.
