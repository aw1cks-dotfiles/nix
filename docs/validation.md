# Validation

This repo exposes a useful `nix flake check`, but it is intentionally narrower than a full rebuild or deployment.

The authoritative implementation is `modules/checks.nix`.

## What `nix flake check` Covers

### NixOS

For each entry in `flake.nixosConfigurations`, the check builds that host's `config.system.build.toplevel`.

This is the strongest validation path currently in the repo.

### nix-darwin

For each entry in `flake.darwinConfigurations`, the check evaluates key resolved values and writes them into a tiny text derivation.

That confirms constructor assembly and important defaults, but it does not build a full darwin system closure.

### Standalone Home Manager

The check builds one synthetic Home Manager activation package per distinct system present in `configurations.home`.

That exercises the Home Manager activation pipeline for the supported systems in the repo, but it is intentionally not a per-host build and does not validate each real host's full closure.

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

Those failures usually surface while evaluating the flake outputs, not only while building the final derivations.

## What `nix flake check` Does Not Prove

`nix flake check` does not prove:

- that a host can successfully switch on a real machine
- that all repo-local Home Manager hosts build end to end
- that darwin system activation succeeds
- that secrets decrypt correctly at runtime
- that downstream consumers still evaluate unless you test them

## Recommended Workflow

Use the narrowest useful validation first.

- shared docs or non-evaluated text changes: static inspection is enough
- constructor, schema, or reusable module changes: `nix flake check`
- host-behavior changes: the relevant rebuild command or narrower host-specific build path
- reusable downstream contract changes: downstream validation with a local override when practical

Desktop-specific note:

- `nix build .#desktop-vm` is the narrowest useful repo-local validation for the `desktop` VM proving path
- the VM path is suitable for validating evaluation, VM assembly, Ly login wiring, embedded Home Manager activation, and remote inspection via the forwarded SSH port
- it is not a complete proof of rendered `niri` behavior on every host GPU stack; on modern NVIDIA hosts, QEMU virtio/virgl rendering can fail even when Ly successfully launches the `niri` user session
- treat rendered compositor behavior, terminal launch, browser launch, and audio as follow-up validation that may need bare-metal confirmation on `desktop` or a nested compositor path on a more compatible host

Provisioning-specific note:

- for the current `disko` integration slice, the narrowest useful validation is evaluation of a real host's resolved `disko` config plus the generated `system.build.diskoScript` derivation path
- that confirms the shared `disko` input is present in the flake contract, imported by the NixOS constructor baseline, and consumable by repo-local hosts such as `desktop`
- full installer-ISO or `nixos-anywhere` validation is not required for this slice because those workflows are tracked as later Stream B items
- for the `nixos-anywhere` workflow slice, the narrowest useful validation is `nix run .#nixos-anywhere -- --help` so the pinned repo-local app resolves and dispatches to the expected CLI without attempting a real install
- for the bootstrap SSH slice, the narrowest useful validation is extending a real repo host with `flake.nixosModules.installer-bootstrap-ssh` and evaluating the resolved root authorized keys plus OpenSSH settings
- for the shared installer ISO slice, the narrowest useful validation is `nix build .#installer-iso` because the primary deliverable is the flake artifact itself
- for the current shared-ISO sufficiency slice, static inspection of the planned host set is enough because `desktop` is the only host that currently needs ISO boot, while VPS-style reinstalls such as `dziewanna` can continue to use the non-ISO `nixos-anywhere` plus kexec path
- for the provisioning wrapper-app slice, the narrowest useful validation is `nix run .#install-host -- --help` or another argument error path that proves the wrapper resolves and prints its usage without attempting an install
- for the VM-backed provisioning validation slice, prefer `nix run .#install-host-vm-test -- <hostname>` because it exercises the repo-local provisioning command shape against `system.build.installTest` without needing a real SSH target
- if that VM-backed path fails with a `qemu-common` signature mismatch, check whether the pinned `disko` revision crossed commit `ec90d55ff3bc330759d3bfbfc254985e08c96b1f`; on the current stable `nixpkgs` base, this repo works around that regression by pinning `disko` to pre-regression commit `5ae05d98d2bebc0a9521c9fc89bd2e5cffa05926`
- if that VM-backed path currently fails inside the pinned `disko` toolchain before boot, record the upstream blocker explicitly and fall back to evaluating `system.build.diskoScript` plus `system.build.toplevel` until the pinned `installTest` path is usable again
- the current expected success path is `nix run .#install-host-vm-test -- desktop`, which should complete the VM-backed `system.build.installTest` run and emit a `vm-test-run-disko-*` store path
If a change affects generated flake output, update `modules/flake-file.nix` and regenerate with `nix run .#write-flake` before validating.
