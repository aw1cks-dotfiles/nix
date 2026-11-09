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


### OMP collaboration package

`checks.<system>.omp-collab` builds the same derivation as `packages.<system>.omp-collab`.
It exercises the loopback/analytics patches, offline Bun dependency installation, relay and browser bundling, and installation of assets and license notices.
Unlike the host-derivation evaluation, this catches build- and install-phase regressions during input-update CI on Linux and Darwin.

The package preserves upstream's MIT license and the CLI's JavaScript notices, which also cover the shared `collab-web` viewer.
It does not build the OMP CLI/native addon to obtain those notices or include the addon's separate notice catalog.
This is a package-build check, not a live Collab session or Tailscale deployment check.

```bash
nix build .#checks.aarch64-darwin.omp-collab --no-link
nix build .#checks.x86_64-linux.omp-collab --no-link
```

### Neovim plugin loading

`checks.<system>.neovim-plugin-loading` exercises require-triggered activation of
real Trouble modules from collision-safe dev paths and direct Nix package paths.
It catches missing runtimepath/configuration registration, including Trouble's
symbol source used by lualine. The actual host's native `home.checks` separately
validate its installed Treesitter parser/query pairs.
See [Neovim integration decisions](./neovim.md) for scope and retained workarounds.

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

Check that `rust-analyzer` resolves to the standalone Nix package while `cargo`
and `rustc` still resolve to rustup. Run the pinned OMP LSP tool in temporary
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
