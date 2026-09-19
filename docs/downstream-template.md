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

## AI Model Routing

The shared Home Manager AI module exposes provider-specific model tiers under `modules.ai.models` so downstream hosts can replace models without copying the OpenCode or OMP agent maps:

```nix
{
  modules.ai.models = {
    frontier = {
      opencode = {
        model = "anthropic/claude-opus-4-6";
        variant = "high";
      };
      omp = "anthropic/claude-opus-4-6:high";
    };

    small = {
      opencode = {
        model = "ollama/qwen3-coder";
        variant = null;
      };
      omp = "ollama/qwen3-coder";
    };
  };
}
```

The available tiers are `frontier`, `premium`, `standard`, and `small`. OpenCode and OMP use different provider namespaces and model-selector syntax, so each tier keeps separate values for the two clients. Setting an OpenCode `variant` to `null` omits the variant.

These tier values feed the shared default agent and model-role assignments. A downstream module can still override an individual assignment directly through `modules.ai.opencode.settings.agent.*` or `modules.ai.omp.settings.modelRoles.*`; those explicit settings take precedence over the shared defaults.

Shared OMP defaults (theme, status line, approval mode, onboarding markers, task isolation/delegation guards, and bash-interception safety policy) are declared per-key with `lib.mkDefault` under `modules.ai.omp.settings`, so a downstream `settings` attrset merges key-by-key instead of replacing the shared block. Downstream modules only declare the deltas — typically model routing and provider policy. Nested defaults are per-subkey (`task.maxRecursionDepth`, `task.agentModelOverrides`) for the same reason: a downstream `task.isolation.*` assignment merges with, rather than replaces, the shared delegation guard.

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
