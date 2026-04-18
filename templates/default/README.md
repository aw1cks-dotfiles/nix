# Downstream Template

This template is a minimal downstream flake that consumes `dendritic-lib` as a shared base and layers repo-local configuration on top.

It is intentionally reference-oriented rather than ready to evaluate unchanged: the example host facts and host declarations remain commented out until a downstream repo supplies real values.

## Layout

- `modules/flake-file.nix`: downstream flake-file source of truth
- `hosts/facts.nix`: declares local host facts through `config.aw1cks.hostFacts`, with commented examples
- `hosts/examples.nix`: commented host configuration examples showing how to import layered profiles
- `modules/org/meta.nix`: example downstream namespace, options, and an identity extension
- `modules/org/git.nix`: example of layering repo-local git behavior on top of the shared identity model
- `modules/org/certificates/ssl.nix`: example of layering an internal CA bundle on top of the shared home-manager stack
- `modules/org/profiles/home/work.nix`: example downstream profile composed from repo-local modules

## Example Layering Pattern

The template shows the intended separation of responsibilities:

- `aw1cks.*` remains the shared upstream contract provided by `dendritic-lib`
- `org.*` is an example downstream-private namespace for local modules, profiles, and options
- host facts select an identity such as `work`
- host configs import downstream profiles like `config.org.profiles.home.work`

This keeps shared library concerns reusable while allowing local repos to add organization-specific settings such as private git hosts, internal CA bundles, or extra package-manager configuration.

## Getting Started

1. Rename or replace the example `org.*` namespace if you want a different downstream-private name.
2. Update `aw1cks.identities.work` in `modules/org/meta.nix` with real values, or remove it if you only need the default identity.
3. Add any internal CA certificates and point `org.ssl.extraCertificateFiles` at them.
4. Uncomment and adapt the example entries in `hosts/facts.nix` and `hosts/examples.nix`.
5. Regenerate the top-level `flake.nix` with `nix run .#write-flake` after changing `modules/flake-file.nix`.
