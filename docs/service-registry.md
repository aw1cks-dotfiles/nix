# Service Registry

This repo does not need a full service registry today. The current requirement is only to preserve a clean seam for one later.

The intended seam is a small derived view such as `flake.lib.serviceRegistry`, built from shared host facts plus any future explicit service declarations. It should stay optional, data-oriented, and narrow in scope until a real downstream need appears.

## Goal

Provide one future place to answer questions like:

- which hosts provide a named service
- which roles commonly imply a service surface
- which hosts are expected consumers of a service

This is a design seam, not a mandate to model runtime discovery, orchestration, health checks, or secret distribution.

## Non-Goals

Do not turn the registry seam into:

- a service discovery system
- a deployment orchestrator
- a secret inventory
- a replacement for host composition roots
- an exported compatibility contract before consumers need one

Facts, composition, and secrets keep the same boundary here as everywhere else in the repo.

## Inputs

Any future registry should derive from safe shared metadata first.

Primary input:

- `hosts/_facts.nix` as exposed through `config.flake.hostFacts`

Possible later inputs, only if a concrete use case appears:

- explicit reusable service declarations under `modules/`
- role-to-service mappings derived from existing profile conventions
- repo-local host annotations that are safe to share

These inputs must remain pure metadata. Local file paths, constructor wiring, and secrets do not belong in the registry.

## Proposed Shape

If the seam becomes useful, prefer a derived library value rather than a new top-level host declaration system.

Example shape:

```nix
flake.lib.serviceRegistry = {
  services = {
    syncthing = {
      providers = [ "mbp" "alex@desktop" ];
      roles = [ "desktop" "interactive" ];
    };
  };

  hosts = {
    mbp = {
      roles = [ "desktop" "developer" "interactive" "multimedia" ];
      services = [ "syncthing" ];
    };
  };
};
```

This shape is intentionally simple:

- `services.<name>.providers` answers where a service exists
- `services.<name>.roles` captures broad intent, not enforcement
- `hosts.<name>.services` gives a host-centric lookup view

The exact schema should only be introduced when there is a real caller.

## Design Constraints

Any future implementation should follow these rules:

- derive from existing facts and reusable module conventions before adding new sources of truth
- keep repo-local hosts as explicit composition roots
- do not infer secrets, credentials, or private endpoints into the registry
- do not make role labels automatically equal service declarations unless that mapping is explicitly documented
- preserve the shared-library boundary so downstream consumers only depend on intentionally exported data

## Relationship To Roles

Roles and services are related but not identical.

- roles describe host intent such as `desktop`, `developer`, or `interactive`
- services describe concrete provided capabilities such as a future `syncthing` or `attic` surface

Roles may inform default service expectations later, but the registry seam should not assume a one-to-one mapping. A role can imply reusable configuration without claiming that every host exposes a user-visible or network-visible service.

## Relationship To Host Facts

Host facts remain the baseline metadata layer.

The registry should consume facts such as:

- host name
- system
- kind
- roles
- safe tags

It should not absorb composition-only values such as:

- host-local module paths
- embedded `home` payloads
- NVIDIA pin files
- constructor-specific wiring

It should never absorb secrets such as:

- `age.secrets.*` declarations
- private endpoints
- tokens or keys

## When To Build It

Introduce a real `flake.lib.serviceRegistry` only when at least one of these becomes concrete:

- a downstream consumer needs a stable lookup surface
- multiple reusable modules need the same service metadata
- docs or automation are repeating hand-maintained service lists

Until then, this document is the contract: preserve the seam, but do not overbuild it.
