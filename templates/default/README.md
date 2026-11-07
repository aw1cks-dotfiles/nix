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
- `justfile`: full copy of the library root justfile, with recipe-surface parity checked upstream

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

## Commands

The canonical interface is `nix run .#rebuild` (also `nix run .` through the
default app), `nix run .#update -- [inputs...]`, and `nix run .#clean -- [days]`.
Update forwards input names and flags to `nix flake update` (except `--flake`),
regenerates at the enclosing checkout's
root, and fetches all input sources, including unused ones. GitHub authentication
is best-effort and confined to update; rebuild never injects a token into NH.
A cold-store rebuild or initial app resolution can still hit rate limits. Clean
defaults to 7 days; `--gc-only` and `--optimise-only` select either operation.
Use `nix run .#update -- nixpkgs` for a single input. Run the app in a different
checkout to update that checkout; use normal `--override-input` flags on
`nix flake check` for local library integration testing.

`just` is optional sugar. Recipes `default`, `rebuild`, `update`, and `clean`
alias the matching shared apps; `gc` and `optimise` alias the clean app with
`--gc-only` and `--optimise-only`. The upstream root/template justfile drift gate
compares recipe lists; copy the full root file after edits, not a reduced subset.

Bootstrap/recovery recipes are intentionally source-based rather than app
aliases: first activation and recovery must not require an evaluating flake or a
built app. **This template does not bundle the Python helper.** Obtain a reviewed
library source checkout and run, from that checkout:

```sh
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py bootstrap standalone-hm '/path/to/consumer#user@host'
python3 -I -S modules/integrations/_cache-bootstrap/bootstrap.py --recovery bootstrap standalone-hm '/path/to/consumer#user@host'
```

Choose the actual owner (`nixos`, `darwin`, or `standalone-hm`) and output name.
The copied `bootstrap`, `bootstrap-cache`, `recover`, `sync-caches`, `check-caches`,
and `probe-cache` recipes require that source path in the consumer checkout;
they are not standalone template commands. See the library's
[`cache bootstrap guide`](https://github.com/aw1cks/nix/blob/main/docs/cache-bootstrap.md)
for prerequisites and recovery limitations.
