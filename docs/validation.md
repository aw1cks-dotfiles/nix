# Validation

This repo exposes a useful `nix flake check`, but it is intentionally narrower than a full rebuild or deployment.

The authoritative implementation is `modules/checks.nix`.

## What `nix flake check` Covers

### Full native host evaluation

`checks.<system>.host-derivations` evaluates every real host targeting that system:

| Configuration | Evaluated root |
| --- | --- |
| NixOS | `config.system.build.toplevel.drvPath` |
| nix-darwin | `system.drvPath` |
| Standalone Home Manager | `activationPackage.drvPath` |

This forces final package selection, assertions, file generation definitions, and activation derivations rather than only selected metadata.
Foreign-system final derivations are not forced by this check.
The result is a small JSON manifest; derivation-path string contexts are removed after evaluation so building the manifest does **not** build or retain the host closures.

CI first runs `nix eval .#checks.<system>.host-derivations.drvPath` to catch full-host evaluation failures before expensive check builds.
Evaluation can still fetch or realize import-from-derivation prerequisites, such as Stylix's packaged theme files.
This deliberately uses the normal evaluator: `nix flake check --no-build` uses read-only evaluation and can fail on a clean store when those prerequisite derivations have not been written yet.
The subsequent normal flake check builds the manifests and existing behavioral checks, not full host systems.

```bash
nix build .#checks.aarch64-darwin.host-derivations --no-link
nix eval .#checks.x86_64-linux.host-derivations.drvPath --raw
```

### NixOS

For each entry in `flake.nixosConfigurations`, the check evaluates key resolved values and writes them into a tiny text derivation.

That confirms constructor assembly, resolved host identity/user wiring, and selected shared defaults without building full system closures in CI.

`checks.x86_64-linux.desktop-niri-config` builds the desktop's actual rendered KDL file and validates it with the configured Niri binary.
Rendering and validation happen at build time, not through `builtins.readFile` during evaluation, so the desktop system derivation remains evaluable on Darwin without a Linux builder.
This check does not build the desktop system closure.

### nix-darwin

For each entry in `flake.darwinConfigurations`, the check evaluates key resolved values and writes them into a tiny text derivation.

That confirms constructor assembly and important defaults, but it does not build a full darwin system closure.

### Standalone Home Manager

The check builds one synthetic Home Manager activation package per distinct system present in `configurations.home`.

That exercises the Home Manager activation pipeline without building a real host's full closure.
The separate `host-derivations` check evaluates every native real activation package, but does not build it.

### Operational command and template contracts

The canonical operational entry points are `nix run .#rebuild`,
`nix run .#update -- [inputs...]`, `nix run .#clean -- [days]`, and `nix run .`
(the default rebuild app). Update forwards input names and flags to
`nix flake update`, rejects `--flake` before changes, and regenerates at the
repository root, then fetches all input sources with `nix flake archive`.
Only update injects a GitHub token, when available; failed lookup must still
execute Nix. Rebuild must not acquire or inject credentials into NH.
Clean defaults to 7 days; `--gc-only` and `--optimise-only`
preserve the separate garbage-collection and store-optimisation workflows.
There is no justfile and `just` is not a runtime dependency.

Bootstrap and recovery remain source-level `python3 -I -S
modules/integrations/_cache-bootstrap/bootstrap.py` commands, not app aliases, so
initial setup can work before flake evaluation succeeds. No wrapper recipes exist,
so there is no second copy of that interface to drift.


### Neovim plugin loading

`checks.<system>.neovim-plugin-loading` exercises require-triggered activation of
real Trouble modules from collision-safe dev paths and direct Nix package paths.
It catches missing runtimepath/configuration registration, including Trouble's
symbol source used by lualine. The actual host's native `home.checks` separately
validate its installed Treesitter parser/query pairs.
See [Neovim integration decisions](./neovim.md) for scope and retained workarounds.

### Shared YAML schema acceptance

The shared contract is `aw1cks.yaml`, exported by
`aw1cks.modules.home.yaml-schemas` and imported by both editors. Sources live in
`modules/home/editors/yaml-schemas.nix` and `modules/home/editors/_yaml-schemas/`.
For this integration, evaluate both rendered editor settings and an additive
downstream Home Manager composition: preserve existing declarations while adding
`kubernetes.extraCRDs`, `kubernetes.manifestGlobs`, and `extraSchemas`. Exercise
served-only CRD versions, release-specific GVK overrides, duplicate-extra
rejection, and intentional `lib.mkForce` replacement of manifest globs.

Runtime acceptance should use the real YAML language server with known multi-doc
resources and List items, checking diagnostics and resource-specific completions.
Unknown GVKs, including unknown List items, must not select an unrelated schema:
they intentionally lack resource-specific editor validation. Run strict
kubeconform separately and require missing-schema failures for unknown GVKs,
without remote fallback or `-ignore-missing-schemas`. Neither path may read
kubeconfig, access a cluster, or guess remote CRD URLs.

Keep SchemaStore coverage for GitLab CI, GitHub Actions, and Compose; check custom
schema associations and explicit modeline precedence independently of Kubernetes.
Pinned local/store schemas can be exercised offline, but SchemaStore and explicit
remote schema URLs may fetch at runtime. Local file schemas need self-contained
references or a derivation containing sibling references. Never put secrets in
schema/CRD fixtures: these sources enter the world-readable store.

The shared package build passed 19 offline regression tests. A fresh-HOME Neovim
runtime, using the real YAML language server, exercised multi-document diagnostics
and completions, unknown-GVK isolation, two additive downstream CRDs, custom-schema
precedence, GitLab/GitHub Actions/Compose/Ansible coverage, and Helm-values
separation with no kubeconfig. Two downstream-style modules appended declarations
to the public host configuration; rendered Zed settings used the same associations.
An additional real Blink-menu smoke opened an unscoped Role YAML file outside a
Git repo: typing `a` under `rules` offered `apiGroups` first from the LSP source.
The server also completed `nonResourceURLs`, `resourceNames`, `resources`, and
`verbs`. The fallback retained GitLab/Actions/Compose/Ansible schemas and explicit
custom-schema precedence without combining catalog and Kubernetes schemas.
The smoke reused the installed, unchanged Avante configuration to avoid the
unrelated OMP package build failure. No system switch, interactive Zed check, or
real private downstream consumer validation was performed.

### Helm editor smoke

A disposable standalone chart, with no kubeconfig, exercised Neovim's real
`helm_ls` and its embedded YAML server. Opening values first selected
`yaml.helm-values` with only `helm_ls`; templates and helpers selected `helm`;
Chart/JSON-schema files and an unrelated YAML neighbor retained their own servers.
Template `.Values` fields completed in the actual Blink menu; hover showed main
and overlay values, definitions reached both values files, and includes reached
the helper. Core Deployment and pinned PrometheusRule schema fields completed.
The evaluated current/legacy Zed embedded-server settings matched Neovim's.

`helm lint --strict` passed. Rendering with the production overlay and validating
against only the local kubeconform schemas reported two valid resources, no
errors or skips. An overlay violating the sidecar schema minimum was rejected
by Helm CLI.

Nested values-file completion did **not** pass: Helm LS 0.5.4 logged a Boolean
`additionalProperties` decode error for the valid sidecar schema. This is an
upstream values-schema generation limitation, not a successful smoke result.
No chart constraints were removed. No full rebuild, interactive Zed smoke, remote
chart-dependency fetching, or cluster operation was performed; the chart/profile
fixtures were removed.

### Ansible editor and project environments

The native fallback toolchain passed playbook syntax checking, offline linting,
and a localhost-only run (three successful tasks, zero changes). A nonexistent
module failed syntax checking and produced an `ansible-lint` editor diagnostic.
A fresh-HOME Neovim smoke completed builtin modules and arguments, Jinja
variables, module hover/source navigation, and `verbosity` in the actual Blink
menu. Conventional playbook/role paths activated Ansible; unrelated YAML and CI
files retained ordinary `yamlls`.

The final project-aware runtime was checked across separate roots in one Neovim
process. Global fallback completed builtin arguments. A trusted `.envrc` exposed
a collection from a nonstandard project-only path; its arguments, hover,
definition, and `threshold` Blink completion worked. The same module remained
unresolved in the global workspace. Trusted `.nvim.lua` activated that project's
`site.yml` without reclassifying another root's `site.yml`. A blocked `.envrc`
prevented server startup, did not execute its contents, and was not silently
bypassed with global tools.

These were disposable runtime/CLI smoke checks, not additional permanent suites.
No profile switch, execution-environment container, remote-host run, Galaxy
installation, or real private downstream validation was performed. The generated
profile reused the installed Avante configuration to avoid the unrelated OMP
package build failure. All smoke projects and isolated trust databases were
removed.

### Tern settings and user services

`checks.<system>.tern` evaluates an enabled native Home Manager fixture through
its final activation derivation, including theme/launcher generation and the
platform's user-service backend. The fixture explicitly uses `package = null`
and an external executable path, so public CI never needs authenticated archives.
It rejects relay enablement without an explicit URL, overlong socket paths,
unsafe theme/plugin names, reserved wrapper names and palettes without eight
ANSI and eight bright colors. Disabled malformed plugin sources stay unevaluated
and install no pointer.
On Linux it also runs the read-only migration guard against an unreachable user
manager and requires it to fail closed.

The check runs standard-library Python regression tests for preserving unrelated
settings/keybindings, managed changes/removals and type transitions, private
permissions, unchanged-file stability, malformed input, symlinks and interrupted
ownership commits. Plugin validator tests cover manifest schema/ID mismatches,
upstream-compatible entries and source containment, including symlink escapes.
Plugin migration regressions cover semantic ID collisions in directories,
symlinks and alias pointers, unchanged source/data contents and permissions,
normal managed-pointer updates and fail-closed inspection errors. Exercise the
generated pre-write guard in a disposable config directory: a legacy copy must
abort before links change, then pass after an explicit move outside the plugin
root without deleting plugin data.
No check activates a real user's home or executes plugin code.

```bash
nix build .#checks.aarch64-darwin.tern --no-link
nix eval .#checks.x86_64-linux.tern.drvPath --raw
```
The real `packages.<system>.tern` is intentionally not a flake-check build:
import its pinned private archive before running `nix build .#tern` on each target
platform. Linux packaging performs a native version install-check after ELF
fixup and generates the real icons in a temporary home. On Darwin, verify the
unchanged bundle and its signature after registration, then run the CLI version
and an isolated GUI/daemon smoke scenario. Executing the signed app in its builder
can trigger macOS app-management metadata and prevent output canonicalisation.


These checks do not prove native keyboard-layout/Option-side dispatch, Linux
systemd runtime behaviour, or desktop rendering. Those require an installed Tern
and isolated runtime scenarios. Headless Tern does not load user themes; verify
custom theme selection in a real window against a separate daemon/socket/home,
not by substituting a built-in theme and calling it a custom-theme test.

For appearance/plugin changes, build an isolated Home Manager fixture with an
external executable, temporary home/config/socket, a custom CSS base and two
ordered `extraCssFiles`. Use `palette = null` to prove the base foreground remains
intact while the last file wins for the overridden terminal background. Open a
real window, inspect its active dark/light wrapper selections and capture both
the screenshot and computed layout colors. Do not activate the fixture over the
user's home.

Exercise a plugin with both host and window entries and a tool supplied only by
`runtimePackages`, with an explicit restricted environment PATH. Require both
halves to record the tool's successful result in writable plugin data. Verify
that a consuming module can disable a profile-enabled registry entry and add its
own source. Stop only the fixture's processes and remove its temporary files.
`checks.<system>.tern.mkFixture [ ... ]` exposes the native Home Manager fixture
for these scenarios without requiring an authenticated archive in public CI.

For the bundled registry, native loading must report all four IDs ready with no
loader problems. Check the Projects panel against the packaged indexer, the Kube
settings status against the real `kubectl` and managed `tern` executables, and
Grafana's unconfigured Query view without adding a backend or credentials. Verify
Kata's CLI version and palette command without connecting to a real daemon.
Use a fresh HOME/XDG tree and kubeconfig; turn off Projects checks in the trial's
private update preferences and set `TERN_KATA_NO_UPDATE_CHECK=1`. Optional tools,
live backend operations and user credentials are separate acceptance scenarios.


### Kata local daemon

`checks.<system>.kata` evaluates an enabled standalone Home Manager service
without importing Tern. It rejects non-loopback listeners, invalid fixed ports
and unsafe state paths; disabled service evaluation does not require its package
or state. Standard-library Python regressions cover private token creation,
reuse without replacement, concurrent initialization and refusal of unsafe
files. The foreign-owner test runs only with root privileges.

```sh
nix build .#checks.aarch64-darwin.kata --no-link
nix eval .#checks.x86_64-linux.kata.drvPath --raw
nix build .#kata --no-link
```

The real package runs the focused upstream browser-session policy regression
before installation. Its install check runs the version command and
`_web-assets-check`, rejecting a release containing only development UI assets.
Neither the service check nor package build activates a user service.

Native runtime acceptance uses a temporary home, state directory and free
loopback port. Start the actual generated runner, verify authenticated health,
create and read a disposable project/issue, require an unauthenticated mutation
to return 401, and reject a second foreground owner without stopping the first.
Also test the alternate browser authorization path with the correct Origin:
`POST /api/v1/ui/session/local` must return 404 without a cookie, invalid token
login must return 401, and valid token login must return session/CSRF credentials
and a cookie. Require a subsequent authenticated browser mutation to succeed.
Open the actual web UI in an isolated browser tab: it must ask for a token, then
show the disposable project after explicit login. CLI and `tern-kata` must still
write/read against the same hardened server. Do not probe a live user's daemon.
After stopping the managed daemon, the configured client must fail rather than
auto-start a replacement; after restart, the same issue and token must persist.
Run the generated `kata` client with no caller `KATA_*` environment and require
authenticated health and issue creation to succeed. In an isolated Tern window,
clear inherited `KATA_HOME`, `KATA_DB`, `KATA_DSN`, `KATA_SERVER` and credential
variables before launching the generated `tern-kata` executable. Confirm that
the same issue renders at a supported pane width without manually injecting the
target connection. This catches login-shell/GUI environment inheritance gaps.
Keep HOME/XDG paths disposable; do not activate a fixture over the user's home
or migrate a live database. This proves the runner and clients, not live
launchd/systemd lifecycle behavior.

### Rust toolchains

`checks.<system>.rust-toolchains` runs the default-selection activation step
against Home Manager-generated links in isolated homes. It covers a relocated
Rustup home (including spaces), conflicting inherited `RUSTUP_HOME`, preservation
of an existing default, dry-run behavior with both absent and populated Rustup
homes, and evaluation-time rejection of the reserved `none` toolchain name.

The check also starts the real shared rust-analyzer and requests definitions in
both `std` and `core`. It covers the nixpkgs source fallback, a compiler with its
own sources, and explicit `RUST_SRC_PATH` precedence. These checks are offline and
do not activate a real home or build the generic-Linux rustup override.

```sh
nix build .#checks.aarch64-darwin.rust-toolchains --no-link
nix build .#checks.x86_64-linux.rust-toolchains --no-link
```


### Agent skills

`checks.<system>.agent-skills` exercises selection layering, `mkForce`, final exclusions, unknown selectors, ID/name collisions, read-only output configuration, and whole-directory replacements.
It builds real assembled outputs to check frontmatter rejection and preservation of references, executable assets, and licence notices.
The check is registered for every configured system independently of the repo's public host inventory.

`checks.<system>.agent-omp-skills` runs the pinned OMP CLI against the actual Home Manager `ompConfig` activation output in temporary homes.
It exercises default/custom/excluded/empty selections, whole-directory extras, retained caller discovery directories and native user skills, and preserved unrelated settings.
It also checks that disabling OMP does not inject its discovery path or configuration activation.
The check invokes `omp skill list <project> --json`, which uses the same skill discovery as a session; it does not merely inspect registry installation metadata.
No check activates the user's real home.

On Linux, `checks.<system>.agent-skills-patches` compiles examples extracted from the assembled upstream skills.
AddressSanitizer/leak checks exercise coroutine move construction, assignment, self-move, empty handles, and exception lifetime.
A userspace executable uses actual liburing header helpers to exercise distinct provided-buffer slots, publication, wraparound, and multishot SQE buffer selection without kernel calls.
No check writes to live `/proc` or enters a kernel debugger.
The liburing/ASAN check is not registered on Darwin.

```bash
nix build .#checks.x86_64-linux.agent-skills \
  .#checks.x86_64-linux.agent-skills-patches
nix build .#checks.aarch64-darwin.agent-omp-skills
```

These checks cover assembly contracts and known example defects, not the safety or correctness of every upstream instruction.
CI compares all guarded skill inputs' locked `narHash` values against the target branch's `flake.lock`.
The protected target branch is the approved baseline; `.github/skill-inputs.json` inventories the guarded sources, not approved hashes.
Unchanged contents allow ordinary maintenance to proceed without review or a PR comment, even if revisions change. If changes are reverted, the reporter removes its previous review comments.
Changed contents leave the required `skill-input-review` commit status pending and skip host builds before Nix installation.
For changed contents, the trusted default-branch reporter maintains one concise PR comment with approval guidance, upstream two-SHA diff links, and a link to the Actions artifact containing the complete exact two-tree upstream diff.
Review the diff, then use GitHub **Approve** on the current PR head with a human account having write, maintain, or admin access.
Bot reviews, PR-author reviews, read-only collaborators, dismissed/superseded decisions, and approvals of an older head cannot authorize changed contents.
A new push or rebase needs fresh approval; comment text, labels, and checkboxes are never approval authority.
Review events automatically rerun the read-only CI gate and host matrix; no manual rerun or hash-update commit is needed.
Dismissal and later review decisions cause the trusted reporter to recompute approval.
The reporter checks out only default-branch code, never executes upstream code, and does not pass its token to Git.
The host flake check still uses `--no-update-lock-file`.

`checks.<system>.agent-skill-input-gate` covers content identity, source validation, current-head human reviews, dismissal/precedence, paginated API results, stale-head races, reporting failures, and review-comment ownership/cleanup.
These are repository CI checks; downstream overrides do not inherit this approval policy.

#### Required-check rollout

The `main` ruleset must require **all four** contexts: `skill-input-review`, `skill-input-gate`, `host-check (x86_64-linux)`, and `host-check (aarch64-darwin)`, with GitHub Actions as their expected source.
The pending commit status blocks unreviewed drift; the gate job must also be required so API/evaluation failures cannot be hidden by skipped host jobs.
GitHub treats skipped jobs as successful, so requiring host checks alone is insufficient.
Pause Renovate automerge during initial rollout: merge these workflows, refresh an open PR to publish the new contexts, add both new requirements, then resume automerge.
The privileged reporter activates only after its workflow and scripts reach the default branch.
Do not mark a pending review `neutral` or `skipped`, and do not bypass these requirements for Renovate.

```bash
python3 -m pytest .github/test_skill_input_gate.py .github/test_skill_input_review.py
nix build .#checks.x86_64-linux.agent-skill-input-gate
```

## What It Also Catches During Evaluation

Constructor assertions still matter even when the final check derivation is small.

Examples include:

- missing `hosts/facts.nix` entries
- target-kind mismatches
- system mismatches
- unknown roles
- invalid standalone Home Manager names
- missing or malformed NVIDIA pin files
- missing resolved usernames or home directories
- NixOS host declarations that fail to resolve hostName, primary user creation, shell policy, or shared SSH defaults

Those failures usually surface while evaluating the flake outputs, not only while building the final derivations.

### Mutable upstream downloads

The `apple-fonts/sf-pro` input uses Apple's unversioned `SF-Pro.dmg` URL.
If Apple replaces that download, clean CI runners can report a NAR hash mismatch even when a local store still contains the older file.
Fetch it with `nix store prefetch-file --refresh --json`, verify the disk image and Apple installer signature, and use `nix hash path` on the downloaded store path to obtain the **NAR** hash rather than the prefetch command's flat file hash.
Update only the affected lock entry after verification, build the font package, and rerun the locked flake checks; do not disable hash verification or refresh unrelated inputs.

## CI binary cache

CI consumes the public `aw1cks-nix` Cachix cache on both Linux and Darwin.
The Cachix action is read-only: pull requests and build steps never receive a publishing token.
Only successful pushes to this repository's `main` branch publish, using the cache-scoped `CACHIX_AUTH_TOKEN` GitHub Actions secret in the final upload step.
Superseded pull-request runs are cancelled, but running `main` jobs are allowed to finish seeding the cache.
There is no `pull_request_target` job.

`packages.<system>.ci-cache` is the explicit upload root: the exact upstream OMP package used by the skill-discovery check, its native library, and its reusable native dependency artifacts.
The build-only artifacts are included deliberately because they are absent from OMP's final runtime closure.
No real host closure or arbitrary store scan is uploaded.
The small GitHub Actions store cache remains a separate acceleration layer; its garbage collection does not replace Cachix retention.

Initial setup:

1. Create the public `aw1cks-nix` cache at Cachix with managed signing.
2. Generate a write token restricted to that cache.
3. Store it without putting it in source or chat:

   ```bash
   gh secret set CACHIX_AUTH_TOKEN --repo aw1cks-dotfiles/nix
   ```

The first trusted `main` run seeds each architecture; a Renovate update can still require a cold build when its derivations change.
Unchanged binaries and native artifacts are reused while retained by the cache.
The shared cache list pins the public `aw1cks-nix` substituter and signing key for host Nix settings and the bootstrap cache configuration.
Existing hosts receive that configuration on their next rebuild; for immediate local use, `cachix use aw1cks-nix` configures the same public cache.

To inspect or build the same upload root without publishing:

```bash
nix build .#ci-cache --no-link --print-out-paths
```

The shell publishing app captures the single `ci-cache` output with `nix build --print-out-paths` and passes it to Cachix as one quoted argument.
It unsets publishing credentials inside the build subshell, leaving them available only to Cachix:

```bash
nix run .#publish-ci-cache -- aw1cks-nix
```

## What `nix flake check` Does Not Prove

`nix flake check` does not prove:

- that a host can successfully switch on a real machine
- that NixOS hosts build their full `config.system.build.toplevel` closure
- that all repo-local Home Manager hosts build end to end
- that darwin system activation succeeds
- that secrets decrypt correctly at runtime
- that downstream consumers still evaluate unless you test them

## Shared language-server smoke checks

Server provisioning needs runtime checks beyond host-derivation evaluation.
For the native Darwin developer host, build the actual user environment and
wrapped editor without activation:

```sh
nix build --no-link .#darwinConfigurations.mbp.config.home-manager.users.alex.home.path
nix build --no-link .#darwinConfigurations.mbp.config.home-manager.users.alex.programs.neovim.finalPackage
```

Check that `rust-analyzer` resolves to the shared Nix toolchain's analyzer while
`cargo` and `rustc` still resolve to rustup. Run the pinned OMP LSP tool in temporary
Nix, Go, and Python projects with the generated profile on PATH; require a
correct definition or hover response, not discovery status alone. Also exercise
a supported project-local server launcher and missing-server discovery.
Run wrapped Neovim with a minimal external PATH to check server availability
and a real LSP request independently of shell setup.

Use fresh HOME/config/state directories and do not activate the real home.
These are manual acceptance checks, not a permanent cross-language test suite;
they do not establish coverage for every language, ACP client, GUI launcher, or
service. See [server ownership and coverage limits](./neovim.md#shared-language-server-packages).
Validate Linux evaluation and the real downstream consumer separately when
available; Darwin execution does not prove Linux runtime behavior.

### Generated OMP LSP configuration

`checks.<system>.agent-omp-lsp` checks the generated `~/.omp/agent/lsp.json`
merge contract: shared defaults, per-key overrides, whole-array replacement, and
new entries. It also runs the pinned OMP config loader against the generated
default and disabled configurations in temporary homes. With real binaries and
matching project markers, Rust (built-in) and TOML (added) must be eligible by
default and absent when disabled. Standalone Compose variants must select
yamlls without `.git`; ordinary standalone YAML must remain ineligible. The
check does not start language servers or prove that each server responds.
Successful runs print only the regression summaries; failures retain the
captured OMP output for diagnosis.

For an installed end-to-end check, rebuild the current host first, then run the
installed clients in temporary project directories with the real `HOME`:

```sh
nix run .#rebuild -- . -H mbp
```

Use the appropriate local host instead of `mbp` on another machine. Require a
real response per server rather than discovery status.

Project layout matters: root markers are matched in the working directory only,
so create a directory per server and start OMP inside it. Expect C# (`symbols`),
Kotlin (`symbols`), F# (`symbols` after a restore, using the shared
`AutomaticWorkspaceInit` setting), TOML (`symbols`), TypeScript (`diagnostics`,
`TS2322`), Bash (`hover`; that server does not implement `symbols`), and Rust
(`symbols`). Compose files are covered by `yamlls` rather than a dedicated
server: without `.git`, check all four Compose basenames for schema diagnostics
and a malformed file for YAML syntax diagnostics.

Also disable Rust via `lspServers` and confirm that OMP no longer selects its
built-in definition. Do not add `sqls` to a probe: it never answers
`diagnostics`, which is why it is not a shared default.

When timing server startup, use the real `HOME`. Overriding `HOME` breaks
`RUSTUP_HOME`, so `cargo metadata` fails and rust-analyzer answers nothing even
though it reports `ready`; that failure looks like a timeout but is a toolchain
problem. Per-call latency can also be raised with the lsp tool's `timeout`
argument instead of changing configuration.

Exercise the write-time hooks in a project whose servers have never started: no
formatting or diagnostics may appear on the first write, and both must appear
after a warm request. Re-check the project-`lsp.json` spawn path in a throwaway
directory, since OMP runs those commands without a trust prompt.

### clangd

`checks.<system>.clangd-policy` runs pinned clangd against the rendered Home
Manager files. It proves C++23 settings survive both compilation databases and
project `.clangd`, C++ `.h` files parse correctly, and the native user config
enables a warning absent from an unconfigured control.

After activation, verify the actual client surface:

- Native policy: Darwin must own `~/Library/Preferences/clangd/config.yaml`,
  with no stale managed XDG copy. Linux uses `$XDG_CONFIG_HOME/clangd/config.yaml`.
  Run with the real `HOME`; setting only `XDG_CONFIG_HOME` does not redirect
  Darwin's lookup.
- Project flags: C++23 source and C++ headers must remain clean using their
  project commands; a deliberately unused C variable must produce
  `-Wunused-variable` through the installed policy. Do not require globally
  injected `-std` flags.
- Root resolution: in a project whose only database is `build/compile_commands.json`,
  the attached client's `root_dir` must be the project root, not `build/`. A
  nested root marker such as `build/compile_commands.json` produces the latter.
- Neovim: load the installed init file, not a handcrafted LSP setup. `-l` alone
  does not exercise normal startup, so use `--headless -u ~/.config/nvim/init.lua`
  with a script loaded via `-c 'luafile ...'`. `vim.wait` for clangd attachment and
  published diagnostics. Confirm real C errors, clean C++23/header cases, and
  that the command starts without unsupported platform flags.

With no compilation database, diagnostics still appear through clangd's generic
fallback but include paths are absent, so `file not found` errors are expected and
do not indicate a broken setup.

## Recommended Workflow

Use the narrowest useful validation first.

- shared docs or non-evaluated text changes: static inspection is enough
- constructor, schema, or reusable module changes: `nix flake check`
- host-behavior changes: `nix run .#rebuild` or a narrower host-specific build path, because `nix flake check` intentionally avoids full NixOS closures
- reusable downstream contract changes: downstream validation with a local override when practical

Darwin GUI package note:

- `dev-gui-apps` takes VS Code from the existing pinned `pkgs.unstable` package set because the stable recipe still uses the old macOS ripgrep path instead of the ASAR-unpacked `ripgrep-universal` layout. Linux retains the stable package.
- Verify this selection with a full `nix run .#rebuild` followed by `code --version`; host-derivation evaluation alone cannot catch unpack or patch-phase failures. The upstream packaging fix is [nixpkgs#543899](https://github.com/NixOS/nixpkgs/pull/543899).

Constructor-owned package-set note:

- constructor changes now include shared `pkgs` wiring for `allowUnfree`, NVIDIA license acceptance, `pkgs.unstable`, and `pkgs.llm-agents`
- for NixOS constructor changes, the narrowest meaningful validation is the affected host's `config.system.build.toplevel` build, not only `nix flake check`
- for standalone Home Manager constructor changes, the narrowest meaningful validation is the relevant `homeConfigurations.<name>.activationPackage`
- for nix-darwin constructor changes, evaluation can be checked from Linux, but a full darwin build still requires a darwin builder or host

Provisioning-specific note:

- for the current `disko` integration slice, the narrowest useful validation is evaluation of a real host's resolved `disko` config plus the generated `system.build.diskoScript` derivation path
- that confirms the shared `disko` input is present in the flake contract, imported by the NixOS constructor baseline, and consumable by repo-local hosts such as `desktop`
- for low-memory VPS reinstall targets such as `dziewanna`, also evaluate the resolved `zramSwap` config and any host-local `boot.kernel.sysctl` reclaim tuning that the bootstrap or kexec path depends on; if the real install needed manual zram intervention once, treat that as host parity that must be encoded in the repo rather than left as operator memory
- full installer-ISO or `nixos-anywhere` validation is not required for this slice because those workflows are tracked as later Stream B items
- for the `nixos-anywhere` workflow slice, the narrowest useful validation is `nix run .#nixos-anywhere -- --help` so the pinned repo-local app resolves and dispatches to the expected CLI without attempting a real install
- for the bootstrap SSH slice, the narrowest useful validation is extending a real repo host with `flake.nixosModules.installer-bootstrap-ssh` and evaluating the resolved root authorized keys plus OpenSSH settings
- for the shared installer ISO slice, the narrowest useful validation is `nix build .#installer-iso` because the primary deliverable is the flake artifact itself
- for the current shared-ISO sufficiency slice, static inspection of the planned host set is enough because `desktop` is the only host that currently needs ISO boot, while VPS-style reinstalls such as `dziewanna` can continue to use the non-ISO `nixos-anywhere` plus kexec path
- for the provisioning wrapper-app slice, the narrowest useful validation is `nix run .#install-host -- --help` or another argument error path that proves the wrapper resolves and prints its usage without attempting an install
- when a host uses `hosts/<name>/bootstrap-pre-kexec.sh`, validate both the wrapper entrypoint and the rendered script path by static inspection, and treat a real SSH-target run as the first meaningful proof that the pre-kexec source-OS preparation actually works
- for the VM-backed provisioning validation slice, prefer `nix run .#install-host-vm-test -- <hostname>` because it exercises the repo-local provisioning command shape against `system.build.installTest` without needing a real SSH target
- because `disko` tracks upstream again, re-evaluate a real host's resolved `disko` config and `system.build.diskoScript` after each lock update; run `nix run .#install-host-vm-test -- desktop` on x86_64 Linux when changes cross the VM test path
- the current expected success path is `nix run .#install-host-vm-test -- desktop`, which should complete the VM-backed `system.build.installTest` run and emit a `vm-test-run-disko-*` store path
- for the disposable SSH-target slice, the narrowest useful validation is a disposable Linux VM with SSH enabled and a temporary root key, then `nix run .#install-host -- <hostname> root@127.0.0.1 ...` against its forwarded port
- for the current disposable SSH-target rehearsal, the narrowest useful validation is `nix run .#install-host-kexec-test`, which builds the repo-local Ubuntu-backed kexec test derived from `nixos-anywhere`'s own upstream test fixture
- keep `nix-vm-test` following `nixpkgs-unstable`; this avoids the removed `python3Packages` alias behavior that broke the disposable SSH-target rehearsal
- upstream `nix-vm-test` now supplies the required memory/CPU options and current `nixos-test-driver` configuration, so the repo consumes it directly without a source patch
- keep the repo-local `nixos-images` input on its own upstream nixpkgs lock rather than making `nixos-unstable` follow the repo's rolling package set; its boot modules can still use options removed from newer nixpkgs (for example, `boot.initrd.systemd.enable`)
- after changing that input, evaluate `packages.x86_64-linux.install-host-kexec-test.drvPath`; this is also supported on Darwin, but building and running the rehearsal requires Linux

If a change affects generated flake output, update `modules/flake-file.nix` and regenerate with `nix run .#write-flake` before validating.
