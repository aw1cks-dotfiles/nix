---
name: downstream-consumer-workflow
description: Use this skill when a change in the public repo affects the private consumer repo or any other downstream flake.
---

# Downstream Consumer Workflow

Use this skill when a change in the public repo affects the private consumer repo or any other downstream flake.

This repo is not only a standalone flake for its own public hosts. It is also intended to be imported by downstream flakes as a reusable library. That means changes here can affect two different interfaces:

- this repo's own host outputs
- the reusable module/profile/schema surface consumed by downstream repos

Be explicit about which interface you are changing.

## When To Use It

- Adding or changing reusable modules or profiles
- Changing `flakeModules` exports
- Changing configuration schemas such as `configurations.home`, `configurations.nixos`, or `configurations.darwin`
- Changing checks, flake inputs, or generated flake behavior that downstream repos rely on

## Preferred Workflow

1. Make the shared change here in the public repo.
2. In the downstream private repo, prefer CLI `--override-input` to point `dendritic-lib` at a local `path:` checkout of this repo.
3. Regenerate the downstream generated `flake.nix` only if you intentionally switch to a persistent file-based override or otherwise change generated flake inputs.
4. Update the downstream repo to consume the new interface.
5. Validate from the downstream repo, because that is the real consumer contract.

## Temporary Local Override Pattern In The Private Repo

Prefer a CLI override for temporary local testing instead of editing downstream repo files.

Typical downstream commands:

```sh
nix flake check --override-input dendritic-lib path:/path/to/public/repo
nix run --override-input dendritic-lib path:/path/to/public/repo . -- switch --flake .
```

Use the real local path for the machine.

## Persistent Local Override Pattern In The Private Repo

Typical private-repo edit in `modules/flake-file.nix`:

```nix
dendritic-lib = {
  url = "path:../nix-public";
  inputs = {
    flake-parts.follows = "flake-parts";
    import-tree.follows = "import-tree";
    nixpkgs.follows = "nixpkgs";
  };
};
```

Then regenerate there:

```sh
nix run .#write-flake
```

Use the real local path for the machine. Keep the override temporary unless the user explicitly wants it committed.

## Downstream Flake-File Contract

When a downstream repo generates its own `flake.nix` via `flake-file`, use this repo's exported `flakeModules.downstream-flake-file` as the shared source of truth for the public library's reusable transitive inputs, alongside the base `flake-file` module.

Reference `modules/_internal/flake-file-inputs/default.nix` and `modules/flake-modules.nix` in this repo when you need the exact contract shape.

Downstream repos should not duplicate those public-library `flake-file.inputs.*` declarations manually unless they are intentionally overriding the contract.

## Interface Rules

- Downstream repos should consume reusable module/profile exports, not repo-local public hosts.
- Prefer adding `flake.profiles.*` instead of making downstream hosts repeat long import lists.
- Be careful with export-surface changes because they can silently change downstream outputs.
- Standalone Home Manager NVIDIA consumers should prefer the top-level `configurations.home.<name>.nvidia` contract instead of wiring `targets.genericLinux.gpu.nvidia` directly.
- If downstream tooling needs to bump NVIDIA pins, keep them in host-local JSON files and consume them through the shared contract.

If a change is only for a public host defined in this repo, keep it scoped to that host output. If a change is reusable, shape it as part of the exported shared interface.

## Verification Checklist

- Confirm the downstream repo still evaluates with the local override in place.
- Run the narrowest downstream validation that exercises the change.
- If generated flake output changed, regenerate it in the relevant repo.
- Call out whether downstream validation was performed and whether the override was a temporary CLI override or part of a committed repo change.
