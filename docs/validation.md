# Validation

This repo exposes a useful `nix flake check`, but it is intentionally narrower than a full rebuild or deployment.

The authoritative implementation is `modules/checks.nix`.

## What `nix flake check` Covers

### NixOS

For each entry in `flake.nixosConfigurations`, the check evaluates key resolved values and writes them into a tiny text derivation.

That confirms constructor assembly, resolved host identity/user wiring, and selected shared defaults without building full system closures in CI.

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
- NixOS host declarations that fail to resolve hostName, primary user creation, shell policy, or shared SSH defaults

Those failures usually surface while evaluating the flake outputs, not only while building the final derivations.

## What `nix flake check` Does Not Prove

`nix flake check` does not prove:

- that a host can successfully switch on a real machine
- that NixOS hosts build their full `config.system.build.toplevel` closure
- that all repo-local Home Manager hosts build end to end
- that darwin system activation succeeds
- that secrets decrypt correctly at runtime
- that downstream consumers still evaluate unless you test them

## Recommended Workflow

Use the narrowest useful validation first.

- shared docs or non-evaluated text changes: static inspection is enough
- constructor, schema, or reusable module changes: `nix flake check`
- host-behavior changes: the relevant rebuild command or narrower host-specific build path, because `nix flake check` intentionally avoids full NixOS closures
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

If a change affects generated flake output, update `modules/flake-file.nix` and regenerate with `nix run .#write-flake` before validating.
