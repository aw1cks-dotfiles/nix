# NixOS Migration Project

This document is the planning source of truth for migrating this repo from a Home Manager focused Linux setup plus a separate experimental NixOS repo into a repo that also owns first-class NixOS hosts.

This document replaces `./nixos-experiments` as the authoritative project plan.

The `nixos-experiments` checkout may still be kept around temporarily as a historical reference during implementation, but no implementation or architectural decision should depend on it remaining present.

## How To Use This Document

This document is a living project record, not a one-time design note.

When implementation work is completed, update this document in the same change or immediately after it.

Documentation updates should normally land alongside the implementation change they describe, not as a later cleanup pass.

At minimum, keep the following sections current:

- the checklist in this document
- the relevant workstream or host section
- validation gates, if a gate has been resolved
- any assumptions that were confirmed, invalidated, or replaced with real implementation details

When updating progress:

- mark completed checklist items as done
- add short status notes where useful
- replace provisional wording with concrete implementation details once they are known
- remove assumptions that are no longer true
- add new assumptions only when they are genuinely needed and not yet resolved

Documentation definition of done:

- a checklist item is not complete until any impacted authoritative docs are updated, or the change explicitly notes why no durable doc update was needed
- durable repo truths belong in the relevant authoritative docs under `docs/`, not only in this migration record
- `docs/nixos-migration.md` tracks project sequencing, status, open gates, and migration-specific decisions
- `docs/architecture.md`, `docs/validation.md`, `docs/downstream-template.md`, and other stable docs track the enduring repo contract after the migration scaffolding is gone

Typical same-change doc expectations:

- architecture, module layout, or export-boundary changes should update `docs/architecture.md`
- validation-surface or build-path changes should update `docs/validation.md`
- downstream reusable-contract changes should update `docs/downstream-template.md`
- host/role workflow changes should update `docs/adding-a-host.md` or `docs/adding-a-role.md` when relevant
- migration sequencing, status, and open decisions should update this document

When an assumption changes:

- update the affected section directly instead of leaving stale text in place
- note the new decision in the checklist or validation-gate area if it changes project scope or sequencing
- prefer turning assumptions into explicit decisions as soon as they are validated

If implementation reveals a meaningful deviation from this plan, update the document before treating the new behavior as the project's intended direction.

## Source Control Policy

Implementation work should be committed in atomic units as it progresses.

This includes design-tracking updates to this document while the migration is in flight.

When a commit changes durable behavior or repo contracts, include the authoritative doc update in the same atomic unit whenever feasible.

However, the final branch history should be rewritten before merge or other long-term publication so that it reads as a clean direct implementation in this repo.

The intended final history must remove all references to temporary scaffolding used during planning and migration, including:

- imported dotconfig material
- the `nixos-experiments` checkout
- this design document itself, if it only served as migration scaffolding

This means the final cleanup target is not just dropping temporary bootstrap commits. Later commits must also be rewritten if their diffs or commit messages still reference temporary scaffolding.

Practical rules:

- create atomic commits for completed work as normal
- keep commit messages focused on the real implementation change wherever possible
- avoid unnecessary references to temporary planning artifacts in later commit messages
- perform a final history rewrite pass once implementation is complete so the resulting history reflects only the durable repo changes

## Implementation Workflow

Implementation should proceed in small end-to-end slices so work can be handed over safely between agents without depending on long conversational context.

Default loop for each slice:

- choose one unchecked checklist item, or one tightly coupled pair of items that cannot reasonably land separately
- re-read the relevant repo files, this document, and any authoritative docs touched by that slice
- implement the smallest complete behavior change that resolves the chosen item
- update this document in the same change to reflect the new status, decisions, or remaining gaps
- update any other authoritative docs affected by the change in the same atomic unit
- run the narrowest useful validation for that slice
- commit the slice before moving on

Preferred slice size:

- one schema change plus the constructor or module wiring it requires
- one reusable module plus the profile membership needed to make it usable
- one provisioning artifact or workflow addition
- one host capability that is naturally end to end
- one resolved validation gate

Avoid batching broad work such as an entire stream into one implementation step.

### Subagent Guidance

Use subagents when they reduce context load or separate investigation from implementation cleanly.

Preferred roles:

- use the `explore` subagent for repo reconnaissance, file discovery, narrow code-path inspection, and evidence gathering
- use the `general` subagent for multi-step supporting work that needs more synthesis, comparison, or sustained reasoning than simple exploration

`explore` is configured with a lower-tier model.

Implications:

- prefer `explore` for fast read-only investigation and concrete evidence collection
- do not delegate architecture decisions, broad design synthesis, or other reasoning-heavy tasks to `explore`
- when a task requires significant judgment, tradeoff analysis, or combining many findings into a recommendation, use `general` or do that reasoning in the primary agent context

Good uses of `explore` in this project:

- locating the files that define a host, profile, constructor, or flake surface
- checking how a current option or module is wired
- gathering evidence before updating the migration plan or architecture docs

Good uses of `general` in this project:

- comparing implementation options for a provisioning flow
- analyzing whether a reusable abstraction belongs in shared modules or should remain host-local
- reviewing a larger slice for cohesion, regressions, or missing documentation updates

### Handoff Rules

Agents should hand over only from a clean, committed state whenever feasible.

Before handing off:

- ensure the current slice is either complete and committed, or explicitly blocked
- make sure `docs/nixos-migration.md` reflects the real project state after the slice
- record any durable architectural, validation, or downstream-contract changes in the relevant authoritative docs
- state clearly what was validated and what remains unvalidated
- leave the next natural checklist item obvious from the document state

Do not rely on conversational context as the primary handoff mechanism.

The durable handoff artifacts are:

- the updated checklist and status notes in this document
- any updated authoritative docs under `docs/`
- the atomic git commit that captures the completed slice

### Validation Expectations Per Slice

Use the narrowest useful validation first.

- docs-only changes: static inspection is sufficient
- schema, constructor, reusable module, or flake-surface changes: `nix flake check` unless a narrower validating path is more appropriate
- host-behavior changes: the narrowest host-specific build or evaluation path that exercises the change
- downstream reusable-contract changes: validate from a downstream consumer when practical

When reporting progress in this document or commit history, note validation that was intentionally not performed if it would normally be expected.

### Definition Of Done For A Slice

A slice is done when all of the following are true:

- the targeted checklist item is implemented or explicitly resolved
- any impacted authoritative docs are updated
- the relevant validation has been run, or a deliberate validation gap is recorded
- the work is committed as an atomic unit

If context is getting large, finish the current slice and commit it rather than starting the next one.

## Checklist

Use this checklist as the top-level project tracker. Update it as work lands.

### Step 0. Planning

- [x] Extract intent from `docs/desktop/`.
- [x] Extract intent from `nixos-experiments`.
- [x] Replace `nixos-experiments` as the planning source of truth with this document.
- [x] Decide that all carried-forward behavior must be rewritten to current repo idioms.
- [x] Decide that final branch history must be rewritten to remove temporary migration scaffolding references.
- [x] Decide that `configurations.home."alex@desktop"` remains in place until the NixOS `desktop` host is validated.
- [x] Decide that the first physical-machine NixOS install for `desktop` should target the spare second disk instead of replacing the current OS in place.
- [x] Decide that the first server shell policy target is plain `bash`.
- [x] Decide that provisioning integrations should remain repo-local operational tooling unless a real downstream reusable contract proves necessary.
- [x] Decide that the `desktop` VM proving path should be a repo-local VM package plus optional launch app, not a temporary host in `hosts/facts.nix`.

### Stream A. Shared NixOS Foundation

- [x] Extend identity schema to carry public SSH authorized keys.
- [x] Add a common NixOS user realization module.
- [x] Add central shell policy selection for desktop vs server behavior.
- [x] Implement the initial server shell policy wiring for plain `bash`.
- [x] Populate `aw1cks.profiles.nixos.desktop` beyond its current placeholder bundle.
- [x] Populate `aw1cks.profiles.nixos.server` beyond its current minimal bundle.
- [x] Add reusable NixOS module atoms for boot, networking, security, audio, and user policy.

### Stream B. Provisioning And Bootstrap

- [x] Add `disko` to the repo's flake inputs and integration surface.
- [x] Add `nixos-anywhere` to the repo's supported provisioning workflow.
- [x] Expose a shared installer ISO artifact from the flake.
- [x] Define and implement the bootstrap SSH access path used by the installer ISO and `nixos-anywhere`.
- [x] Expose common provisioning flows through repo-local flake `apps` if the wrapper meaningfully improves the supported install path.
- [x] Validate that one shared installer ISO is sufficient for current planned hosts.

### Stream C. `desktop`

#### C0. VM Proving

- [x] Choose the repo representation for the `desktop` VM proving path.
- [x] Bring up the initial `desktop` graphical stack in a VM-oriented path.
- [x] Validate preferred `ly + niri` session behavior in the VM path, keeping `ly` and documenting the compositor rendering limits of the VM path.
- [x] Validate terminal launch, browser launch, and basic desktop workflow in the VM path.
- [x] Record the bare-metal-only gaps that remain after VM proof, especially NVIDIA and host-specific hardware behavior.

Representation decision:

- use a repo-local `perSystem.packages.desktop-vm` target derived from `configurations.nixos.desktop`
- keep `desktop` as the single canonical host composition root
- layer VM-only concerns on top of that host through `extendModules`
- do not introduce a temporary VM host in `hosts/facts.nix`
- expose both a repo-local package and a launch app:
  - `packages.desktop-vm`
  - `apps.desktop-vm`

Current VM proving surface:

- `nix build .#desktop-vm` builds the VM runner derived from `desktop`
- `nix run .#desktop-vm -- --help` resolves and dispatches to the generated QEMU launcher
- `nix run .#desktop-vm-smoke` runs an automated Ly-to-`niri` smoke test that confirms the resolved desktop user can launch `wezterm`, `zen-twilight`, and a VM-backed PipeWire default sink in the VM session
- the VM path intentionally proves the graphical stack shape without claiming bare-metal NVIDIA, disk, or hardware parity
- the VM variant enables OpenSSH with host-port forwarding on `localhost:2222` so Ly/session behavior can be inspected remotely while the local console is owned by Ly
- the current repo-local proving result is that Ly successfully authenticates and launches the `niri` user session in the VM path, so the graphical login gate stays on `ly`
- the same VM path does not currently prove compositor rendering on this host: with modern NVIDIA host drivers, QEMU virtio/virgl combinations either leave `niri` running without visible outputs or fail to present a usable framebuffer entirely
- treat that rendering failure as a host/virtual-GPU limitation of the proving environment, not as evidence that `desktop` must switch from `ly` to `greetd`
- terminal, browser, and a VM-backed PipeWire default sink are now covered by the repo-local smoke test; rendered compositor behavior and host-speaker playback still need bare-metal validation or a nested compositor path on a host that can actually support the required virtio/virgl stack

#### C1. Base OS

- [x] Add `desktop` to `hosts/facts.nix` as a NixOS host.
- [x] Declare `configurations.nixos.desktop` in `hosts/desktop/configuration.nix` alongside the existing standalone Home Manager host during migration.
- [x] Add `hosts/desktop/hardware-configuration.nix`.
- [x] Add `hosts/desktop/disko.nix`.
- [x] Evaluate whether a close `nixos-hardware` profile exists for `desktop`.
- [x] Add the initial `desktop` GPU/hardware path.
- [x] Add `ly` as the first planned display manager.
- [x] Add host-local `niri` session wiring.
- [x] Validate successful graphical boot with `ly + niri`, or switch to the documented `greetd` fallback if the Ly gate fails.
- [x] Validate terminal launch, browser launch, and audio.

#### C2. `niri` / `noctalia-shell`

- [x] Revisit whether to switch `desktop` from nixpkgs `programs.niri` to `niri-flake` for Nix-native compositor configuration after the graphical login path is stable.
- [x] Add initial `noctalia-shell` integration.
- [x] Move launcher behavior into `noctalia-shell`.
- [x] Move notification behavior into `noctalia-shell`.
- [x] Recreate required shell widgets and panel behavior.
- [x] Port the required desktop workflow intent from `docs/desktop/`.

### Stream D. `dziewanna`

#### D1. Host And Service Parity

- [ ] Add `dziewanna` to `hosts/facts.nix` as a NixOS host.
- [ ] Add `hosts/dziewanna/configuration.nix` declaring `configurations.nixos.dziewanna`.
- [ ] Add `hosts/dziewanna/hardware-configuration.nix`.
- [ ] Add `hosts/dziewanna/disko.nix`.
- [ ] Recreate the static public-IP NetworkManager configuration in host-local rewritten form.
- [ ] Preserve the WAN-facing SSH posture: OpenSSH on `222`, `endlessh` on `22`, password login disabled, root login disabled.
- [ ] Port Murmur service behavior.
- [ ] Port ACME configuration and certificate wiring.
- [ ] Validate that live service parity is preserved.

#### D2. Refinement

- [ ] Promote repeated server behavior into reusable NixOS modules only after parity exists.
- [ ] Reduce host-local one-offs only where the reuse case is real.

### Validation Gates

- [x] Resolve the graphical login gate for `desktop` (`ly` preferred, `greetd` fallback if needed).
- [ ] Resolve the `nixos-hardware` gate for `desktop`.
- [x] Resolve the initial server shell policy gate: plain `bash` first.
- [x] Resolve whether one shared installer ISO remains sufficient.
- [x] Add and validate an explicit shared installer ISO build path.
- [ ] Validate downstream consumer evaluation after shared schema, constructor, or reusable-contract changes.
- [x] Resolve the `desktop` VM proving-shape gate.
- [ ] Complete the final history rewrite pass to remove temporary migration scaffolding references.

## Goals

- Rebuild the current Home Manager host `alex@desktop` as a real NixOS desktop host named `desktop`.
- Replace the current Arch Linux X11 desktop stack with a NixOS Wayland stack built around `niri`.
- Replace the current `leftwm` and `eww` desktop stack with `niri`, then layer `noctalia-shell` on top after the base graphical session is stable.
- Bring the existing `dziewanna` server host into this repo as a first-class NixOS host.
- Establish reusable NixOS modules and profiles in the current repo's idioms instead of relying on host-local ad hoc imports or the old experiment repo's structure.
- Support reproducible provisioning with `disko` and `nixos-anywhere`.
- Expose a repo-supported bootstrap artifact, preferably a single installer ISO suitable for USB boot.

## Non-Goals

- Mechanically porting modules, files, or structure from `nixos-experiments`.
- Preserving the old repo's assembly model, option namespaces, or host constructors.
- Generalizing `niri` or `noctalia-shell` into a reusable desktop-wide default before at least one real host proves the abstraction.
- Solving long-term SSH key lifecycle improvements such as CA-backed auth during this migration. Public authorized keys are sufficient for now.

## Source Intent Inventory

The project draws intent from two places.

### `docs/desktop/`

This directory is the source of truth for the current user-facing desktop behavior on `alex@desktop`.

Important preserved intent:

- Super-based workspace and window management.
- Fast app launching.
- Notification delivery.
- Compact shell surface with workspaces, media state, system metrics, and clock.
- Keybinds for browser, terminal, screenshots, media, and desktop control.
- Overall dark, compact visual style.

The implementation does not need to match the old X11 toolchain. It only needs to preserve or intentionally replace the behavior.

### `./nixos-experiments`

This repo is intent input only.

Relevant intent extracted from it:

- reusable NixOS baselines for boot, networking, audio, locale, security, and GPU support
- `ly` as the preferred display manager
- `disko`-based host partitioning
- `nixos-anywhere`-compatible provisioning mindset
- host-local network and disk layouts
- `dziewanna` live service behavior, especially networking, SSH posture, Murmur, and ACME
- a distinction between desktop-oriented and server-oriented systems

The following must not be imported conceptually as architecture:

- `my.system.*`
- `mksystem.nix`
- the old host assembly pattern
- the old module tree layout
- per-user NixOS configuration files as the primary composition model

## Planning Rule

Everything carried forward from `nixos-experiments` must be rewritten to fit the current repo's architecture.

In this repo, the stable architectural split is:

- reusable schema, modules, and profiles live under `modules/`
- repo-local host composition roots live under `hosts/`
- host metadata lives in `hosts/facts.nix`
- constructors own host assembly and role expansion

Therefore:

- reusable intent becomes `aw1cks.modules.nixos.*` atoms or `aw1cks.profiles.nixos.*` bundles
- host-specific disk, hardware, network, and session choices remain under `hosts/<name>/`
- provisioning interfaces should be exposed via repo-local flake `packages` or `apps`
- provisioning support should not expand the reusable downstream contract unless a real downstream consumer proves that boundary is needed

## Target Architecture

## Shared NixOS Layer

This repo should grow a real NixOS layer analogous to its existing Home Manager and darwin layers.

The intended shape is:

- atomic reusable modules in `aw1cks.modules.nixos.*`
- thin reusable bundles in `aw1cks.profiles.nixos.*`
- repo-local host roots in `hosts/<name>/configuration.nix`

### Required Profiles

These profiles should exist up front, even if initially thin:

- `aw1cks.profiles.nixos.desktop`
- `aw1cks.profiles.nixos.server`

These profiles should remain bundles, not catch-all host dumps.

### Likely Reusable NixOS Modules

Exact filenames can be chosen during implementation, but the reusable surface should cover these concerns:

- boot baseline
- systemd-boot / EFI support
- network baseline
- OpenSSH and WAN-facing server security baseline
- PipeWire audio baseline
- Wayland baseline
- display manager support
- NVIDIA baseline
- common user realization
- provisioning and installer support where it belongs in the flake surface

The reusable layer should be broad enough to support both `desktop` and `dziewanna`, not just the workstation.

## Identity-Driven User Model

The migration introduces a common NixOS user module shared between desktop and server hosts.

### Identity Layer Responsibilities

The identity layer should own stable public identity data, including:

- username
- full name
- email
- home directory when needed
- public SSH authorized keys

Public keys are in scope for this migration. More seamless future auth such as host certificates or a CA-based setup is out of scope.

### Common User Module Responsibilities

The common NixOS user module should own:

- user creation for the resolved primary user
- shell selection
- role-aware extra groups
- wiring authorized keys from the selected identity

The common user module should not own:

- secret or bootstrap passwords
- host-specific service users
- one-off local group membership unrelated to reusable host intent

Implementation sequencing note:

- extend identity schema first
- then add the common NixOS user realization module
- then layer shell policy selection on top of that shared user path

### Shell Policy

Shell policy should be centrally selected by option or value, not by ad hoc raw module wiring in each host.

The design must allow:

- desktop hosts to use a richer shell stack
- server hosts to use a lighter shell stack
- server hosts to fall back to plain `bash` if desired

The current heavy Home Manager `zsh` module should not be assumed appropriate for servers.

Initial implementation decision:

- server shell policy starts with plain `bash`
- richer desktop shell behavior can be layered later without blocking the shared NixOS baseline

## Provisioning Architecture

Provisioning is a first-class project concern.

### Required Tools

- `disko` for host partitioning and filesystem layout
- `nixos-anywhere` for unattended installation

### Bootstrap SSH Access

The provisioning design needs an explicit bootstrap SSH access story before the final host user exists.

Decision:

- the shared installer ISO should expose a repo-defined bootstrap access path suitable for running `nixos-anywhere`
- that bootstrap access path should install operator public keys deliberately, rather than assuming the final common user module already ran
- the bootstrap access path is temporary installer behavior, not part of the durable host user model
- current repo-local implementation: `flake.nixosModules.installer-bootstrap-ssh`
- this module enables OpenSSH in the installer environment, permits key-only root login, and requires explicit `aw1cks.provisioning.bootstrapAuthorizedKeys` rather than assuming the final host identity contract

Repository boundary:

- bootstrap SSH access for the installer environment belongs with repo-local provisioning tooling
- the common NixOS user realization module remains responsible for the final installed machine's primary user and long-lived authorized keys
- do not couple installer/root access to the final host user's existence

Initial implementation shape:

- the shared installer ISO should carry an explicit bootstrap SSH module or profile that authorizes the operator key(s) needed for install-time access
- the direct-boot flow should rely on that installer access path
- the existing-Linux reinstall flow should use whatever SSH entrypoint already exists on the source machine, without assuming the final NixOS user is present before installation
- current repo-local module path: `flake.nixosModules.installer-bootstrap-ssh`

### Bootstrap Artifact

The preferred bootstrap artifact is a single installer ISO exposed from the repo.

This should be suitable for:

- writing to a USB stick
- booting a machine into a NixOS installer environment
- serving as the stable bootstrap path for `nixos-anywhere`

The default assumption is one shared artifact. Host-specific bootstrap artifacts should only be introduced if a host later proves to require one.

Current sufficiency decision:

- sufficient for the current planned host set in this repo
- `desktop` is the only current planned host that needs direct-boot removable-media installation, and it is an `x86_64-linux` machine using ordinary EFI boot plus host-local `disko`
- the shared minimal installer ISO already carries the explicit bootstrap SSH path needed for both direct-boot install and `nixos-anywhere`
- `dziewanna` does not weaken this decision because its provisioning path is an existing-Linux or VPS reinstall flow via `nixos-anywhere` and kexec over the provider base OS, not an ISO-boot flow
- there is no current planned host that forces a second installer architecture, board-specific installer payload, or alternate bootstrap access path
- revisit this decision only when a new planned NixOS host proves a concrete need for a different architecture, storage prerequisite, or installer-time hardware dependency

Repository boundary:

- the installer ISO and any provisioning helpers are repo-local operational outputs
- they should be exposed through flake outputs in this repo
- they should not be treated as part of the reusable downstream contract unless a real consumer needs them

Current repo-local output:

- `packages.installer-iso` builds a shared minimal installer image that imports `flake.nixosModules.installer-bootstrap-ssh`
- the current shared image seeds bootstrap root SSH access from `aw1cks.identity.selected.authorizedKeys` by setting `aw1cks.provisioning.bootstrapAuthorizedKeys` inside the installer build
- `apps.install-host` wraps the common `nixos-anywhere` invocation shape by filling in `--flake "$repo_root#<hostname>"` and `--extra-files hosts/<hostname>` from the requested repo host
- `apps.install-host-vm-test` wraps `nixos-anywhere --vm-test` for a repo host so provisioning can be preflighted without a real SSH target

### Supported Provisioning Paths

The design should support two primary installation paths.

#### Direct Boot

- boot from the installer ISO
- authenticate through the installer environment's explicit bootstrap SSH access path
- run `nixos-anywhere` against the target flake host
- use `disko` and the host's NixOS configuration to complete installation

#### Existing Linux Reinstall

- install from an existing Linux system such as the current Arch Linux on `desktop`
- use the existing machine's current SSH entrypoint for `nixos-anywhere`
- allow the tool to handle the normal bootstrap flow where appropriate
- do not assume the final NixOS primary user or authorized-keys wiring already exists on the preinstall system

Custom kexec images are not required for the initial project shape.

### VM-Backed Provisioning Validation

Before a real target host is available, the smallest useful provisioning proof should use `nixos-anywhere --vm-test` through a repo-local wrapper.

This VM-backed path is intended to prove:

- the repo's `nixos-anywhere` wrapper arguments resolve the intended flake host
- the host's `disko` layout and install closure can be exercised through `system.build.installTest`
- the supported provisioning command shape remains runnable from this repo

Current caveat:

- the repo-local wrapper is in place as `nix run .#install-host-vm-test -- <hostname>`
- the current `disko` default branch is temporarily incompatible with this repo's stable `nixpkgs` line for `system.build.installTest` because commit `ec90d55ff3bc330759d3bfbfc254985e08c96b1f` switched `disko` to the newer `nixos/lib/qemu-common.nix` interface (`{ lib, stdenv }`) while stable 25.11 still exposes the older `{ lib, pkgs }` form
- to keep VM-backed provisioning validation working on the repo's current stable base, the repo pins `disko` to pre-regression commit `5ae05d98d2bebc0a9521c9fc89bd2e5cffa05926`
- with that pin in place, `nix run .#install-host-vm-test -- desktop` now completes successfully and produces a `vm-test-run-disko-*` result path

It is not intended to prove:

- installer ISO boot behavior
- bootstrap SSH access to a live installer environment
- provider-specific VPS or bare-metal quirks
- the full remote kexec or SSH control path used by a real reinstall

Use it as a fast preflight check, not as a substitute for eventual direct-boot or VPS-host validation.

### Disposable SSH-Target Validation

After the pure `--vm-test` preflight passes, the next stronger provisioning proof should target a disposable Linux VM over SSH.

This disposable-target path is intended to prove:

- `nix run .#install-host -- <hostname> <target-host>` works against a real SSH endpoint rather than only `system.build.installTest`
- the repo's `--extra-files hosts/<hostname>` bootstrap material is accepted by `nixos-anywhere`
- the normal remote control flow can reach kexec or later install phases without requiring real hardware first

Current implementation shape:

- `apps.install-host-kexec-test` builds a disposable Ubuntu-backed SSH target rehearsal using `nixos-anywhere`'s own `linux-kexec-test.nix`
- the current rehearsal scope is intentionally limited to the `desktop` host and the `kexec` phase, matching the smallest realistic proof we want before risking disk changes in a disposable VM
- `nix-vm-test` follows `nixpkgs-unstable` here because the forked test harness still assumes the older `python3Packages` alias behavior that breaks against this repo's stable 25.11 package set

Current implementation note:

- the repo-local `install-host-kexec-test` path now patches the imported `nix-vm-test` source so its generated driver command uses the current `nixos-test-driver` argument shape: `--vm-names`, `--vm-start-scripts`, and explicit empty container lists from the pinned `nixpkgs-unstable` input
- this keeps the rehearsal runnable on the repo's current dependency set without changing the supported `install-host` wrapper contract

It is still not intended to prove:

- installer ISO boot behavior
- provider-specific VPS networking and console recovery behavior
- final bare-metal firmware or hardware quirks

Use it as the smallest realistic rehearsal for the `dziewanna`-style reinstall path when no real target host is available.

## Host Strategy

## `desktop`

### Target Shape

- facts key: `desktop`
- flake host: `configurations.nixos.desktop`
- hostname: `desktop`

Migration stance:

- keep the existing standalone Home Manager host `configurations.home."alex@desktop"` in place until the NixOS host is validated
- [ASSUMPTION] both paths can coexist during migration because the first physical NixOS install can target the machine's spare second disk
- do not treat the migration as an in-place overwrite of the current desktop OS until the NixOS path is proved acceptable

### VM Proving Path

Before the first bare-metal cutover attempt, the project should prove as much of the graphical environment as possible in a VM-oriented path.

Purpose:

- validate the shared NixOS desktop baseline without depending on host-specific bare-metal hardware work
- prove `ly`, `niri`, terminal, browser, and basic desktop workflow wiring early
- reduce the scope of the first physical-machine install to hardware-specific concerns such as NVIDIA and final disk layout behavior

Expected limits of the VM path:

- it will not prove final NVIDIA behavior
- on modern NVIDIA hosts, it may not prove rendered `niri` output at all even when Ly and the user session wiring are otherwise correct
- it will not replace host-local `hardware-configuration.nix`
- it will not replace the need for final bare-metal validation on the real `desktop` machine

Open shape question:

- represent the VM proof as a repo-local VM package plus optional launch app
- do not represent the VM proof as a temporary `flake.nixosConfigurations.<vm-name>` host
- keep the long-term canonical host identity as `configurations.nixos.desktop`
- keep VM-only concerns in host-local repo code rather than in shared reusable profiles or constructor contracts

Source-of-truth rule:

- the VM proof should consume the same host-local desktop base module stack that the eventual `configurations.nixos.desktop` host will import
- VM-only overrides should be layered on top of that shared host-local base, not assembled as a separate ad hoc desktop system
- if needed, split reusable host-local desktop baseline code under `hosts/desktop/` so both the VM package and the final host root import the same base

Implementation guardrail:

- the VM proof path must not duplicate constructor-owned identity resolution, baseline imports, or embedded Home Manager policy beyond what is strictly necessary before `configurations.nixos.desktop` exists
- the VM proof should be treated as an alternate build target for the same intended `desktop` system shape, not as an independent prototype environment

### Desktop Milestones

#### C0. VM Proving

This milestone should produce a VM-oriented graphical validation path before the first bare-metal migration attempt.

Required behavior:

- a VM-oriented build/install path exists in the repo
- preferred `ly` login works in that path, or the documented `greetd` fallback is taken
- `niri` session launches
- terminal launches
- browser launches
- remaining bare-metal-only gaps are documented explicitly

Current status:

- complete for login/session and launch-path validation: the VM path now demonstrates that `ly` launches the `niri` user session, embedded Home Manager activation completes successfully, and the resolved desktop user can launch `wezterm`, `zen-twilight`, and a VM-backed PipeWire default sink through a repo-local smoke test
- still not a complete rendered desktop proof on the current host: QEMU on this NVIDIA-backed machine can leave `niri` running without a usable visible output even when the session itself is healthy
- remaining meaningful validation for this stream is now host-specific: rendered compositor behavior, host-speaker playback, and NVIDIA still need bare-metal validation or a more compatible nested-compositor proving path

#### C1. Base OS

This milestone should produce a bootable graphical desktop host.

Required behavior:

- NixOS host builds and provisions successfully
- `hosts/desktop/configuration.nix` declares `configurations.nixos.desktop`
- host uses `disko`
- host can be installed via the shared provisioning path
- graphical login works, with `ly` preferred and `greetd` accepted only if the Ly gate fails
- `niri` session launches
- embedded Home Manager works
- terminal launches
- browser launches
- audio works

`noctalia-shell` is explicitly not required for this milestone.

The first physical-machine migration should prefer the spare second disk so the current desktop OS remains available while the NixOS host is being proved.

Current status:

- complete for the accepted graphical-login path: the repo-local `desktop-vm-smoke` path proves that Ly authenticates successfully, launches the `niri` user session, and reaches a usable user session for terminal, browser, and VM-backed audio validation
- no `greetd` fallback is needed from the current evidence because the unresolved VM limitation is rendered output on this NVIDIA-backed proving host, not Ly session behavior
- remaining host-specific validation is still bare-metal oriented: rendered compositor output, NVIDIA behavior, and host-speaker playback quality remain outside the current VM proof

#### C2. Desktop Shell Layer

This milestone adds the new shell stack after the compositor/session base is stable.

Required behavior:

- integrate `noctalia-shell`
- move launcher behavior into `noctalia-shell`
- move notification behavior into `noctalia-shell`
- add shell widgets and panel behavior
- re-express the current desktop UX from `docs/desktop/` in Wayland-native form

Current status:

- complete for the first shell-layer landing: `desktop` now imports `inputs.noctalia.homeModules.default` through its embedded Home Manager payload, enables `programs.noctalia-shell`, and seeds an initial compact bar layout in `hosts/desktop/noctalia-home.nix`
- `desktop` also enables the host services that Noctalia expects for the current scope: NetworkManager was already part of the shared network baseline, and the host now explicitly enables Bluetooth, UPower, and `power-profiles-daemon`
- the current startup path remains repo-local and host-local: under the nixpkgs `programs.niri` session, Noctalia is launched via an XDG autostart desktop entry instead of promoting a reusable desktop-shell abstraction yet
- launcher trigger migration is now in place for the preserved `Super+D` workflow: `hosts/desktop/niri/config.kdl` binds `Mod+D` to `noctalia-shell ipc call launcher toggle`, replacing the old `rofi -show run` path with a Noctalia-native launcher entry point
- notification behavior is now owned explicitly by Noctalia instead of an implicit daemon default: `hosts/desktop/noctalia-home.nix` configures top-right notifications with persistent history, muted notification sounds, and 8-second urgency timeouts matching the old `dunst` shape closely enough for the first Wayland landing
- shell widget and panel parity has now moved into Noctalia's declarative settings: the host-local bar layout keeps launcher plus workspaces on the left, media centered, and system metrics plus notification history, clock, and control center on the right, while the attached control-center cards surface the closest first-pass replacement for the old compact `eww` side widgets and status affordances
- desktop voice-chat workflow has an initial compositor-safe landing as well: `hosts/desktop/niri/config.kdl` preserves the old `Super+Shift+KP_Enter` Mumble self-deafen toggle by calling `mumble rpc toggledeaf`, which works cleanly as a one-shot compositor bind under Wayland
- true push-to-talk remains a follow-up item rather than a pure `niri` bind because Wayland background key capture is compositor-owned and `niri` keybinds are not a good press-and-release transport; the likely next step is a small external helper that listens for a chosen input event and calls Mumble `starttalking` / `stoptalking`
- the remaining desktop workflow intent from `docs/desktop/` now has a host-local `niri` landing as well: `hosts/desktop/niri/config.kdl` restores the old Super-based workspace and window controls, app launch shortcuts for terminal, browser, music, and Mumble, media keypad controls, and desktop-control binds for close, fullscreen, and session exit
- the Wayland-native replacements are explicit where the old X11 stack was tool-specific: `Mod+Print` now uses `niri`'s built-in screenshot UI instead of `flameshot gui`, while TeamSpeak and Steam launch shortcuts were left out because those applications are not currently part of the desktop package set proven by this repo
- the repo-local desktop VM smoke test now also waits for a live `noctalia-shell` process after the `niri` user session comes up

### `niri` Placement

`niri` should remain host-local initially.

Rationale:

- `desktop` is the only confirmed NixOS Wayland desktop host in scope
- `desktop` profile should mean desktop-capable baseline, not a hardcoded compositor choice
- the compositor abstraction can be promoted later if repeated by another host

Current landing for `desktop`:

- host-local module: `hosts/desktop/niri.nix`
- enables `programs.niri`
- enables polkit and XDG portal wiring needed for a usable Wayland session
- adds `xwayland-satellite` for XWayland application support
- routes portal file chooser requests to GTK to avoid requiring Nautilus in the initial host path

Decision after revisit:

- keep `desktop` on nixpkgs `programs.niri` for now
- the current host-local `niri` module only needs the compositor package, session wiring, portal behavior, and XWayland support; that is already covered cleanly enough by nixpkgs plus the small host-local wrapper
- switching to `niri-flake` now would widen the flake-input surface without unlocking a concrete repo need, because no host-local Nix-native `niri` settings or generated compositor config are being expressed yet
- revisit `niri-flake` only when `desktop` starts declaring substantive host-local compositor configuration in Nix, such as keybinds, outputs, layout rules, Noctalia integration hooks, or other settings that benefit from the flake's config-generation surface

### Display Manager

Preferred path:

- use `ly`

Fallback path:

- switch to `greetd` if Ly cannot provide reliable enough session behavior for `niri`

The implementation should treat Ly as the intended default, not as a temporary placeholder, but it should keep a documented fallback path.

Current landing for `desktop`:

- reusable module: `aw1cks.modules.nixos.ly`
- imported by `hosts/desktop/configuration.nix` as the first graphical login path
- `greetd` remains the documented fallback only if Ly later fails the `niri` session-behavior gate

### GPU and Hardware Strategy

The first pass should prefer a minimal known-good local NVIDIA baseline.

However, the project should evaluate `nixos-hardware` as an optional upstream hardware module if a close hardware match exists for the actual machine.

Policy:

- if a close `nixos-hardware` profile exists, it may be imported as additive host support
- if not, the host should proceed with local hardware configuration and a minimal local NVIDIA baseline
- `nixos-hardware` does not replace host-local ownership of `hardware-configuration.nix`, `disko`, session setup, or compositor choices

Decision for `desktop`:

- no sufficiently close board-specific `nixos-hardware` profile was found for the machine
- current known hardware: Gigabyte Aorus X570 Xtreme motherboard, AMD Ryzen 9 5950X CPU, NVIDIA RTX 3090 GPU
- use additive generic upstream modules instead of a board-specific profile
- accepted initial additive set:
  - `common-pc`
  - `common-pc-ssd`
  - `common-cpu-amd`
  - `common-cpu-amd-pstate`
  - `common-gpu-nvidia-nonprime`
  - `common/gpu/nvidia/ampere`
- host-local ownership remains responsible for `hardware-configuration.nix`, `disko`, session setup, compositor choices, and any NVIDIA details not covered by the generic modules

Initial local NVIDIA baseline for `desktop`:

- reusable module: `aw1cks.modules.nixos.nvidia`
- imported additively by `hosts/desktop/configuration.nix`
- enables NVIDIA video driver selection, Wayland-compatible modesetting, CUDA cache, 32-bit graphics support, VA-API/Vulkan packages, and basic NVIDIA tooling
- keeps bus-ID/PRIME laptop policy out of scope because `desktop` is a discrete-GPU machine using the non-PRIME path

### Host-Local Ownership For `desktop`

These concerns should remain under `hosts/desktop/`:

- `hardware-configuration.nix`
- `disko.nix`
- any host-specific hardware imports
- `niri` config and session behavior
- later `noctalia-shell` config and shell behavior

## `dziewanna`

`dziewanna` is its own migration stream, not a side effect of desktop work.

### Target Shape

- facts key: `dziewanna`
- flake host: `configurations.nixos.dziewanna`
- server-oriented NixOS host using the new shared layer

### First-Pass Requirements

The first pass must preserve live deployed behavior, not just produce a bootable host.

Required behavior:

- base OS migration into current repo structure
- preserved static public-IP network configuration
- preserved SSH posture
- preserved Murmur service
- preserved ACME configuration and certificate usage

### Preserved SSH Posture

The following is considered intentional default behavior for a WAN-facing server and should be preserved in the migration:

- OpenSSH on port `222`
- `endlessh` on port `22`
- password login disabled
- root login disabled

This should likely become part of the server-side reusable security baseline, with host-local overrides still possible.

### Preserved Networking

`dziewanna`'s static IP and NetworkManager profile configuration should be preserved as host-local rewritten intent.

This configuration is live and should not be generalized prematurely.

### Preserved Services

The first-pass migration must include:

- `services.murmur`
- ACME setup
- firewall behavior required for Murmur and HTTP challenge handling

This is required because the existing server is already live with these services deployed.

### Host-Local Ownership For `dziewanna`

These concerns should remain under `hosts/dziewanna/` unless repeated elsewhere later:

- static network configuration
- host disk layout
- hardware config
- Murmur specifics
- ACME certificate naming and host-specific wiring

## Workstreams

The migration should be executed as distinct workstreams.

### Step 0. Intent Extraction And Shape Definition

Purpose:

- capture intent from `docs/desktop/` and `nixos-experiments`
- define the target architecture in current repo idioms
- eliminate the need for the old repo as a planning source

Status:

- complete at the planning level through this document

Additional decisions already made:

- keep the existing standalone Home Manager `alex@desktop` path until the new NixOS `desktop` path is validated
- use plain `bash` as the first server shell policy
- treat provisioning outputs as repo-local tooling by default
- prioritize `desktop` before `dziewanna`
- use a repo-local VM package plus optional launch app for the `desktop` proving path rather than a temporary VM host

### Stream A. Shared NixOS Foundation

Purpose:

- create reusable NixOS modules and profiles in the repo's current architecture

Implementation phases inside this stream:

- A1. identity schema extension for public SSH authorized keys
- A2. common NixOS user realization module
- A3. central shell policy selection with plain `bash` as the first server target
- A4. shared NixOS module atoms and thin desktop/server profiles

Expected outcomes:

- real NixOS module vocabulary under `aw1cks.modules.nixos.*`
- `aw1cks.profiles.nixos.desktop`
- `aw1cks.profiles.nixos.server`
- identity extension for public SSH keys (completed in `modules/schema/identity.nix` and reflected in the downstream template)
- common NixOS user realization module (completed in `modules/nixos/user/default.nix` and wired through the NixOS constructor)
- central shell policy selection (completed in `modules/nixos/user/shell-policy.nix` with profile-owned defaults for desktop vs server)

Status note:

- A1 is complete. Validation for this slice used in-repo evaluation paths only; the downstream template was treated as reference material rather than a ready-to-evaluate consumer.
- A2 is complete. The shared NixOS user module now owns primary-user creation, bash as the current baseline shell, baseline `wheel` access, and authorized keys from the selected identity.
- A3 is complete. `aw1cks.user.shellPolicy` now selects the primary NixOS user shell centrally, with `server` defaulting to plain `bash` and `desktop` defaulting to `zsh`.
- A4a is complete. `aw1cks.profiles.nixos.desktop` is now a real bundle with the shared NixOS runtime baseline plus the desktop shell-policy default, leaving graphics, audio, and display-manager concerns for later host-focused slices.
- A4b is complete. `aw1cks.profiles.nixos.server` now imports a shared `aw1cks.modules.nixos.server-security` baseline that establishes the first reusable WAN-facing SSH posture: OpenSSH on `222`, `endlessh` on `22`, password login disabled, and root login disabled.
- A4c is complete. The shared NixOS atom surface now includes boot, kernel selection, systemd-boot/EFI, network baseline, PipeWire audio, and Wayland environment modules, with conservative wiring into the desktop/server profiles.

### Stream B. Provisioning And Bootstrap

Purpose:

- expose a supported install path for new NixOS hosts

Expected outcomes:

- shared installer ISO artifact in flake outputs
- `disko` integration
- `nixos-anywhere` install path
- explicit bootstrap SSH access path for installer and reinstall flows
- optional repo-local flake `apps` wrapping common provisioning workflows

Status note:

- B1 is complete. `disko` is already part of the repo's exported flake-input contract, is imported centrally through the NixOS constructor baseline, and is exercised by the repo-local `desktop` host via `hosts/desktop/disko.nix`.
- B2 is complete. `nixos-anywhere` is now pinned as a repo-local bootstrap input and exposed through `nix run .#nixos-anywhere -- <args>` so installation commands use a reproducible repo-supported entrypoint instead of an unpinned upstream flake URL.
- B3 is complete. The repo now exposes `nixosModules.installer-bootstrap-ssh`, a repo-local installer and kexec module that enables key-only root SSH access from explicit `aw1cks.provisioning.bootstrapAuthorizedKeys` without relying on the final host user module.
- B4 is complete. The repo now exposes `packages.installer-iso`, a shared minimal installer image that imports `nixosModules.installer-bootstrap-ssh` and seeds bootstrap root access from the repo's selected operator identity.
- B5 is complete. One shared installer ISO is sufficient for the current planned hosts in this repo because `desktop` is the only host that needs ISO boot today, while `dziewanna` remains an existing-Linux or VPS reinstall target reached through `nixos-anywhere` and kexec over the provider base OS.
- B6 is complete. The repo now exposes `nix run .#install-host -- <hostname> <target-host> [nixos-anywhere args...]`, which wraps the repeated repo-specific `nixos-anywhere` arguments and keeps the supported install surface discoverable.
- the next provisioning slice should move beyond Stream B and return to the next unresolved host migration gate.

### Stream C. `desktop`

#### C0. VM Proving

- repo-local VM proving shape
- shared host-local desktop base consumed by both the VM path and the eventual `configurations.nixos.desktop` host
- graphical session validation before bare-metal cutover
- explicit capture of remaining bare-metal-only gaps

#### C1. Base OS

- host facts entry
- repo-local host root declaring `configurations.nixos.desktop`
- hardware config
- disk layout
- display manager
- compositor session
- audio and browser/terminal validation

#### C2. `niri` / `noctalia-shell`

- desktop shell migration
- launcher and notifications under `noctalia-shell`
- workspace, media, and shell widgets
- visual and workflow parity with current desktop intent

### Stream D. `dziewanna`

#### D1. Host And Service Parity

- host facts entry
- repo-local host root declaring `configurations.nixos.dziewanna`
- disk and hardware config
- static network config
- SSH posture
- Murmur and ACME

#### D2. Refinement

- tighten reusable server modules only after live parity exists
- reduce one-off host wiring only where genuinely repeated

## Validation Gates

These are implementation-time validation gates that should be tracked in the project but do not block the planning document from being authoritative.

### Graphical Login Gate

Question:

- does `ly` launch the `niri` session cleanly enough for acceptable systemd user session behavior?

If yes:

- keep `ly`

If no:

- switch `desktop` to `greetd`

Completion rule:

- the gate is considered resolved when `desktop` has one documented accepted graphical login path
- `ly` remains the preferred outcome
- `greetd` is an accepted final outcome only if the Ly path was tried and rejected for the stated session-behavior reason

Resolution:

- resolved in favor of `ly`
- the VM proving path confirms that Ly authenticates successfully and launches the `niri` user session
- the remaining VM limitation is compositor rendering on this host's NVIDIA-backed QEMU path, not Ly session behavior, so it does not justify a `greetd` fallback

### Hardware Module Gate

Question:

- is there a sufficiently close `nixos-hardware` profile for `desktop`?

If yes:

- import it additively in the host

If no:

- proceed with local hardware and minimal NVIDIA support

Resolution:

- no close board-specific upstream profile exists for `desktop`, but the gate is satisfied by importing the accepted generic AMD/NVIDIA/common PC modules additively

### Shell Policy Gate

Question:

- should server shell policy land on light `zsh` or plain `bash` first?

Decision:

- plain `bash` first

### Bootstrap Artifact Gate

Question:

- is one shared installer ISO enough for all planned hosts?

Default answer:

- yes

Only split into host-specific bootstrap artifacts if a real provisioning need emerges.

Validation requirement:

- the shared installer ISO must have an explicit repo build path and validation step rather than relying only on host toplevel checks

Resolution:

- resolved in favor of one shared installer ISO for the current repo host set
- justification: `desktop` is the only current host that needs removable-media installer boot, it is `x86_64-linux`, and it uses standard EFI boot; `dziewanna` is instead a VPS-style reinstall target that can continue to use the non-ISO `nixos-anywhere` plus kexec path over its provider base OS

### Downstream Contract Gate

Question:

- do shared schema, constructor, profile, or reusable NixOS surface changes still evaluate in a downstream consumer?

Default answer:

- validate after Stream A changes and again before final merge if the reusable contract changed materially

### `desktop` VM Shape Gate

Question:

- should the VM proving path be a dedicated temporary host, a VM-oriented build target for `desktop`, or another repo-local validation shape?

Decision:

- use a repo-local VM package plus optional launch app
- keep VM-only settings in host-local code under `hosts/desktop/`
- do not add a temporary VM host to `hosts/facts.nix`

## Migration Rules

The following rules apply during implementation.

- Do not port files mechanically from `nixos-experiments`.
- Prefer reusable NixOS modules for behavior repeated across hosts.
- Keep host-specific disks, hardware, networks, and sessions in `hosts/<name>/`.
- Preserve live deployed server behavior before attempting cleanup or abstraction.
- Keep `desktop` compositor and shell choices host-local until repetition justifies promotion.
- Expose provisioning through flake outputs rather than ad hoc scripts.
- Treat this document as the planning source of truth from this point onward.
- Keep implementation commits atomic while the work is in progress.
- Rewrite final history before merge or durable publication so temporary migration scaffolding is removed from the branch history.

## Success Criteria

The migration is complete when all of the following are true.

- the repo contains a real reusable NixOS layer
- the repo exposes a supported provisioning path using `disko` and `nixos-anywhere`
- `desktop` is a real NixOS host in this repo and reaches a stable graphical-login-plus-`niri` base milestone, using `ly` unless the graphical login gate forces the documented `greetd` fallback
- `desktop` later reaches a stable `niri + noctalia-shell` desktop shell milestone
- `dziewanna` is a real NixOS host in this repo with preserved live network, SSH, Murmur, and ACME behavior
- the project no longer needs `nixos-experiments` for planning or architectural guidance

## After This Document

After this document is committed, it becomes the source of truth for the migration plan.

`./nixos-experiments` may still be used briefly as a historical implementation reference, but the repo should be considered disposable once:

- the shared NixOS layer exists
- the host plans are encoded in this repo
- no unresolved live behavior remains undocumented
