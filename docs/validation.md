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

If a change affects generated flake output, update `modules/flake-file.nix` and regenerate with `nix run .#write-flake` before validating.
