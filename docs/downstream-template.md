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

## Layering Model

The template demonstrates a simple split:

- `aw1cks.*` stays the shared upstream namespace
- a downstream-local namespace such as `org.*` holds private modules, profiles, and options
- `hosts/facts.nix` provides downstream host metadata
- `hosts/default.nix` is the explicit downstream host loader
- host configuration roots import downstream profiles and local modules as needed

This keeps shared library concerns reusable while giving the downstream repo room for private certificates, private git settings, internal package sources, and site-specific policies.

## Shared agent skills

`modules.ai.skillsSource` exposes the bundled `context7` and `git-workflow` skill directories for downstream agent harnesses.
Skill loading stays task-dependent; agent selection remains in the client's configuration rather than a bundled routing policy.

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

### Oxocarbon themes

The shared AI module installs `~/.omp/agent/themes/oxocarbon-dark.json` when OMP is enabled and defaults `modules.ai.omp.settings.theme.dark` to `oxocarbon-dark`.
The JSON palette is adapted from [Oxocarbon.nvim](https://github.com/nyoom-engineering/oxocarbon.nvim); OMP does not change the terminal's background, so use `#161616` in the terminal for a matching canvas.
Downstream configurations can override the dark theme through the existing per-key settings interface; the light-theme slot is unchanged.

The shared CLI tools module supplies the checked-in `oxocarbon-dark.tmTheme` through `programs.bat.themes.oxocarbon-dark.src` and selects it with `programs.bat.config.theme`.
Home Manager installs the theme and rebuilds bat's cache during activation; no manual `bat cache --build` step is needed after switching.
The theme's source of truth is `modules/home/shells/files/bat/oxocarbon-dark.tmTheme`, not a mutable file under `~/.config/bat/themes`.

Delta uses the same palette: `modules/home/vcs/default.nix` declares a `delta "oxocarbon"` feature with `syntax-theme = "oxocarbon-dark"` and selects it via `programs.delta.options.features`. The syntax theme ships with delta's embedded bat themes, so no extra theme file is required.

After switching, check `bat --list-themes` for `oxocarbon-dark` and launch OMP normally to use its declared dark-theme default.

## Self-Hosted OMP Collab Over Tailscale

OMP collab is an opt-in feature of the existing AI module:
`modules.ai.omp.collab.enable`. AI-enabled homes keep it disabled by default;
this repo opts in only `mbp`. Enabling it installs two loopback-only user
services: the upstream OMP WebSocket relay and its browser client, using the
existing locked `oh-my-pi` input and offline Bun dependency cache. The packaged
browser client removes upstream's external analytics script.

Add the machine's full Tailscale HTTPS hostname, without the trailing DNS dot,
to its existing entry in `aw1cks.hostFacts` in `hosts/facts.nix`:

```nix
tailnetHost = "mbp.example.ts.net";
```

Then opt in through the AI configuration in the **flake-parts host composition
module**; do not repeat the hostname here:

```nix
{ ... }:
{
  configurations.darwin.mbp.home.modules.ai.omp.collab = {
    enable = true;
    # autoStart = "view"; # or "control"; default "off" requires /collab
  };
}
```

Replace the illustrative host key and facts hostname with your own. The
`developer` role already imports the AI module; homes without that role must
import `config.aw1cks.modules.home.ai` in their Home Manager composition.
The same AI surface works with standalone Linux and embedded NixOS homes.
Constructors forward the matching `hostFacts` into Home Manager, including
embedded homes, and already import the required `programs.omp` schema. Raw
Home Manager consumers must provide `extraSpecialArgs.hostFacts` and the AI
module's other prerequisites, including
`inputs.oh-my-pi.homeManagerModules.default` exactly once.

There is no separate collab module import, `services.omp-collab` option, or
collab hostname override: the hostname comes only from `hostFacts.tailnetHost`
and is required only when collab is enabled. The AI module consumes service
options rather than forwarding them to `programs.omp`.

The feature supplies defaults for `collab.webUrl`, `collab.relayUrl`, and
`collab.autoStart`; explicit OMP settings still take precedence. Sharing stays
manual by default. `modules.ai.omp.collab.autoStart = "view"` or `"control"`
explicitly opts into sharing every interactive session at that access level.

After rebuilding/switching the selected host, publish the services with
[Tailscale Serve](https://tailscale.com/docs/reference/tailscale-cli/serve):

```sh
tailscale serve status
tailscale serve --bg --https=443 http://127.0.0.1:7467
tailscale serve --bg --https=8443 http://127.0.0.1:7466
```

Inspect the existing Serve configuration first: these commands claim the root
endpoint on each specified HTTPS port. If either port is already in use, choose
different `modules.ai.omp.collab.webHttpsPort` / `relayHttpsPort` values
and use those ports in the commands. Under the same option group, `webPort`
(default `7467`) and `relayPort` (default `7466`) control the local listeners.
All ports must be nonzero; the two local ports must differ, as must the two
HTTPS ports.

The feature deliberately does not modify Tailscale configuration or tailnet
policy during activation. Both devices need Tailscale, the tailnet needs HTTPS
certificates enabled, and its access rules must permit the published ports.
Use **Serve, not Funnel**, to keep access within the tailnet. Serve supplies
trusted HTTPS/WSS, which the browser's WebCrypto requires; a plain HTTP tailnet
IP is not sufficient.

Start a new OMP process after switching so it reads the declared URLs, run
`/collab`, and open its browser link or QR code in Safari on the phone. For an
already-running process, update **Interaction → Collab** in `/settings` to the
same URLs: `https://mbp.example.ts.net` and
`wss://mbp.example.ts.net:8443` with the defaults above. Stop an existing room
with `/collab stop` before starting one on the new relay. This shares the
running session rather than importing its transcript into another agent.

Full-control links grant prompting, interruption, and supported guest actions;
treat them as credentials. `/collab view` prints a read-only link. Model/session
administration such as `/model`, `/compact`, and `/resume` remains host-only.
The included relay is upstream development tooling, not its private production
Go service; keep it private. Restarting the relay disconnects current rooms,
and manual rooms require starting `/collab` again and reopening the new link.
Tailscale itself can still use an encrypted DERP transport if a direct peer
connection is unavailable.

On macOS, Home Manager manages launchd agents named
`org.nix-community.home.omp-collab-web` and
`org.nix-community.home.omp-collab-relay`; logs are
`~/.omp-collab-web.log` and `~/.omp-collab-relay.log`. On Linux, the units are
`omp-collab-web.service` and `omp-collab-relay.service`; inspect them with
`systemctl --user status` and `journalctl --user -u <unit>`.

Disabling the option removes the managed user services on the next switch, but
does not remove separately configured Serve endpoints. Remove only the
endpoints you added (adjust ports if customized), rather than resetting all
Serve configuration:

```sh
tailscale serve --bg --https=443 off
tailscale serve --bg --https=8443 off
```

The reproducible package is also available with `nix build .#omp-collab`.
It provides `omp-collab-relay --port PORT` and `omp-collab-web --port PORT`;
neither downloads dependencies at runtime. `nix run .#omp-collab -- --port 7466`
runs only the relay, not the web service or Tailscale publication.

## Private Paseo With The OMP Plugin

The AI module also provides `modules.ai.paseo`. It is disabled by default and
enabled only for `mbp` in this repo:

```nix
configurations.darwin.mbp.home.modules.ai.paseo.enable = true;
```

After the host switch, Home Manager starts the daemon automatically through
launchd on macOS (`org.nix-community.home.paseo`) or a systemd user service on
Linux (`paseo.service`). It runs as the existing user, not a separate service
account. Logs are `~/.paseo-service.log` on macOS and the user journal on Linux.

Paseo is pinned to upstream **0.15.0**, revision
`8938fde3c713143f12eacbdd60c11fdfc0be0fb1`, through the shared `paseo` input and
the generated flake/lock. Its Nix recipe has a narrow runtime-closure correction
to retain the plugin compiler worker, TypeScript and native esbuild executable.
The **OMP Plugin 5.2.3** npm archive and published production shrinkwrap are
integrity-pinned and installed offline by Nix. No global npm install or runtime
plugin dependency download is required. Update these through Nix, not Paseo's
plugin updater. The artifacts are exposed as `packages.paseo` and
`packages.paseo-omp-plugin`.

The plugin is registered as `paseo-omp` and contributes **OMP Plugin**
(`omp-plugin`); select that provider, not Paseo's separate bundled `omp`
provider. `OMP_COMMAND` points to the existing `programs.omp.package` binary.
The daemon retains the real user `HOME`, existing `~/.omp/agent` configuration
and credentials, and Nix/user-profile tool paths. OMP provider login remains an
ordinary user operation through OMP; credentials are not copied into a derivation.

### Networking And Phone Setup

Both services use `hostFacts.tailnetHost`; do not repeat the hostname in Paseo
configuration. Default listeners and private Serve ports are:

| Service | Loopback listener | Tailnet HTTPS port |
| --- | --- | --- |
| OMP collab browser | `127.0.0.1:7467` | `443` |
| OMP collab relay | `127.0.0.1:7466` | `8443` |
| Paseo daemon | `127.0.0.1:6767` | `9443` |

Paseo's `port` and `httpsPort` options must not collide with enabled collab
listeners/mappings; the module asserts this. It never opens a firewall port or
modifies Serve on activation. Inspect the current configuration, then add only
the dedicated Paseo mapping:

```sh
tailscale serve status
tailscale serve --bg --https=9443 http://127.0.0.1:6767
```

If that HTTPS root is already occupied, choose another
`modules.ai.paseo.httpsPort` and matching Serve command. Do not overwrite collab's
443/8443 mappings, use Funnel, or reset the entire Serve configuration.
Tailscale HTTPS certificates and access rules permitting the dedicated port
are required. The managed daemon forcibly disables Paseo's hosted relay and
optional public service-proxy listeners, including when an older config enabled
them. Relay enablement cannot be changed through the running daemon.

On the phone, connect Tailscale and open Paseo:

1. **Settings → Add host → Direct connection**.
2. Host: the machine's full `hostFacts.tailnetHost`; for this Mac,
   `mbp.gentoo-boa.ts.net`.
3. Port: `9443` by default. Enable **Use SSL**.
4. Enter the password from the private file described below.
5. Create an agent with **OMP Plugin**.

The default Mac endpoint is `https://mbp.gentoo-boa.ts.net:9443`.
Do not enable Paseo's hosted relay or use relay-based pairing. This is a direct
authenticated HTTPS/WebSocket connection through the tailnet's Serve proxy.
Tailscale may still transport encrypted packets through its own DERP relay.

### Passwords, Persistence And Adoption

`modules.ai.paseo.stateDirectory` defaults to `~/.paseo`.
`passwordFile` defaults to `~/.config/paseo/password` (under the configured XDG
config directory). Both options are absolute **strings** naming writable paths
outside `/nix/store`; never put the password value in Nix.

For a fresh instance, first service startup generates a random password once
in a user-owned `0600` regular file. Read that file locally to enter the password
in the app; do not paste it into configuration, logs, or a URL. An existing custom
password file must be a private user-owned regular file, not a symlink, containing
one nonempty line. Empty, symlinked or group/world-accessible files stop startup.
The service writes only a bcrypt hash to its private writable `config.json`;
the plaintext is not placed in the store or exported to agent processes.

If an existing Paseo config already has a password but the managed file is
missing, startup refuses to replace it: provision `passwordFile` with the
existing password first. Stop any already-running Paseo instance before
adoption. The wrapper refuses an existing supervisor before modifying state,
and the native supervisor takes its PID lock atomically; an unmanaged running
daemon is never silently accepted as an authenticated managed instance.

Rebuilds/restarts retain the password, matching bcrypt hash, sessions,
`plugin-settings`, `plugin-data`, daemon identity and other user state. Only
managed listen/hostname/auth/relay policy and the pinned OMP plugin registration
are reconciled in `config.json`; other settings and plugin registrations remain.
There are no Home Manager store symlinks replacing the mutable state tree.

To rotate the password, replace the private file securely and restart the
**managed service**, then update the phone's saved password. On macOS:

```sh
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.paseo"
```

On Linux use `systemctl --user restart paseo`. Do not start a second daemon with
Paseo Desktop or `paseo daemon start`; this feature owns the supervisor and its
security environment.

Disabling the option removes the user service on switch, but preserves its
password/state. Separately remove only the Serve mapping you added:

```sh
tailscale serve --bg --https=9443 off
```

### Verification

`checks.<system>.paseo-state` checks password/hash preservation, private-file
rejection, existing-password adoption and password-file rotation against the
real pinned daemon's bcrypt implementation.

The integration was exercised on aarch64 macOS with temporary user state:
native daemon startup, unauthenticated/wrong-password rejection, authenticated
HTTP and WebSocket access through the actual private tailnet HTTPS endpoint,
**OMP Plugin** reporting Ready with eight models, duplicate-supervisor refusal,
and restart preservation of the password/hash and user-state marker. No model
turn or physical iPhone UI was exercised, and no full Home Manager/system switch
was performed. The temporary Serve mapping was removed after verification.

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
