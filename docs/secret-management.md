# Secret Management

> Agenix-based secret management for this repository's NixOS, nix-darwin, and standalone Home Manager hosts.

## Contents

- [Scope](#scope)
- [Design Goals](#design-goals)
- [Repository Boundaries](#repository-boundaries)
- [Secret Taxonomy](#secret-taxonomy)
- [Bitwarden And Agenix](#bitwarden-and-agenix)
- [Threat Model](#threat-model)
- [Key Inventory](#key-inventory)
- [Recipient Strategy](#recipient-strategy)
- [Host Onboarding Flow](#host-onboarding-flow)
- [Platform Notes](#platform-notes)
- [Operational Procedures](#operational-procedures)
- [Incident Response](#incident-response)
- [Decryption Lifecycle](#decryption-lifecycle)
- [Encryption At Rest](#encryption-at-rest)
- [Suggested Inventory Layout](#suggested-inventory-layout)
- [Dependencies](#dependencies)

---

## Scope

This document describes a cohesive secret-management approach for this repo.

It complements:

- [`docs/architecture.md`](./architecture.md) for repository architecture and facts boundaries
- [`docs/adding-a-host.md`](./adding-a-host.md) for the host addition flow

This repo already wires agenix into all three constructor paths:

- NixOS via `modules/constructors/nixos.nix`
- nix-darwin via `modules/constructors/darwin.nix`
- standalone Home Manager via `modules/constructors/home-manager.nix`

Repository tooling should be exposed through flake `apps` or `packages`, not as undocumented ad hoc scripts. This repo already follows that pattern for commands such as `nix run .#write-flake`, `nix run .#home-manager`, `nix run .#darwin`, and `nix run .#update-nvidia-version`.

This document does not put secrets into `hosts/facts.nix`. Facts remain safe shared metadata only.

---

## Design Goals

- **No shared private key material**: each private key is exclusive to its holder.
- **Unattended NixOS operation where needed**: NixOS hosts can reboot and activate secrets without operator presence.
- **Manual bootstrap is acceptable for darwin and standalone Home Manager**: extra setup work is fine if it improves clarity and least privilege.
- **Break-glass access**: an admin can recover any secret if primary admin hardware is unavailable.
- **Operational simplicity**: routine rebuilds should remain straightforward once a host is enrolled.

---

## Repository Boundaries

This repo separates host metadata, host composition, and secrets.

- `hosts/facts.nix` contains only safe shared metadata such as `system`, `kind`, `roles`, `user`, `homeDirectory`, and `hostName`
- `hosts/<name>/configuration.nix` contains repo-local host composition
- agenix wiring is enabled by the shared constructors, not by facts
- `age.secrets.*` declarations belong in the relevant host or reusable module layer
- encrypted secret material and recipient inventory should stay outside `hosts/facts.nix`

Never put any of the following into `hosts/facts.nix`:

- secret values
- private keys
- agenix-managed payloads
- `age.secrets.*` content
- local bootstrap-only secret material

---

## Secret Taxonomy

Classify secrets by both **consumer** and **scope**.

Consumers:

- **human-only**: a person retrieves and uses the secret manually
- **machine**: a host, service, agent, or CLI process needs the secret locally
- **mixed-use**: both a person and a machine need the same credential

Scopes:

- **per-host**: one credential per machine
- **shared machine**: one credential used by several machines
- **global admin**: recovery or administrative credentials with broad access

Recommended categories in this repo:

| Category | Example | Default authority | Preferred recipient scope |
|----------|---------|-------------------|---------------------------|
| Human-only | site login, cloud console password | Bitwarden | No machine recipient |
| Mixed-use workstation | local CLI LLM key on `mbp` | Bitwarden | Admins plus one host only if persistent local access is worth it |
| Per-host machine | host-specific API token | `agenix` | Admins plus that host |
| Shared machine | Wi-Fi PSK, shared service token | `agenix` | Admins plus only required hosts |
| Global admin | break-glass recovery key metadata | offline storage plus admin process | Admin-only |

Prefer per-host machine credentials whenever the upstream provider supports them. Shared credentials should be the exception, not the default.

---

## Bitwarden, Gopass, And Agenix

These tools solve different problems and should not be treated as interchangeable.

- **Bitwarden** is for human-managed credentials and account-level secure notes.
- **`gopass`** is the preferred lane for interactive local CLI secrets that should be injected only when needed.
- **`agenix`** is the machine-delivery mechanism for repo-managed secrets that must exist on Nix-managed hosts at activation or runtime.

Recommended split:

- keep human-only credentials in Bitwarden
- keep interactive workstation CLI secrets in `gopass`
- keep machine runtime and repo-managed secrets in `agenix`

Default authority rules:

- human-only: Bitwarden authoritative
- interactive local CLI/workstation secrets: `gopass` authoritative
- machine runtime: `agenix` authoritative

If a secret exists in more than one system, define one source of truth explicitly. Rotations should update the authoritative system first, then any replica.

Bitwarden remains useful for non-secret operational metadata such as:

- recipient fingerprints
- key serial numbers
- secret owners
- rotation dates
- links between provider-side credentials and repo-managed `.age` files

Break-glass recovery must not depend solely on Bitwarden availability.

### API Tokens And CLI Credentials

Developer API tokens, including LLM keys, often blur the line between human and machine use.

Use this rule: classify them by execution context.

- occasional manual use: Bitwarden only
- repeated interactive use on one workstation: `gopass`
- unattended local agents, services, or jobs: `agenix`

For machine-delivered API keys, prefer one credential per host when the upstream provider supports it.

That improves:

- compromise isolation
- revocation per host
- auditing and attribution
- safer machine retirement

Be careful with CLI-delivered API keys. They are easy to leak through:

- shell history
- environment propagation
- subprocess inheritance
- debug logs
- config dumps

Prefer targeted process-local loading over blanket global shell exports.

For this repo's current direction, that means:

- do not export local developer API keys globally from shell startup by default
- prefer wrappers, shell functions, or tool-specific launchers that fetch from `gopass` only for the command that needs the secret
- keep `agenix` for secrets that truly need to exist for unattended machine use

### Gopass And Age

`gopass` has an `age` backend and appears to fit this architecture well for interactive local secrets.

Supported upstream capabilities include:

- native `age` identities
- SSH recipients and SSH identities
- encrypted SSH private keys
- age plugins, including YubiKey-based identities
- an age agent for passphrase caching

Recommended role in this repo:

- use `gopass` for local, interactive, workstation-scoped secrets such as CLI/API tokens
- keep those secrets out of git by default
- inject them only when launching the tool that needs them
- treat them as disposable or easily replaceable unless explicitly documented otherwise

### Assumptions And Unknowns

The conclusions above rely on upstream `gopass` documentation and source inspection, not on a validated local workflow in this repo yet.

Current assumptions:

- [ASSUMPTION] `gopass` versions with current age support use `gopass age identities add`, not the older `gopass age identity add`
- [ASSUMPTION] `gopass` can participate in the same age trust model as the rest of this architecture without requiring a separate crypto root
- [ASSUMPTION] using `gopass` for interactive local secrets is operationally simpler than committing many disposable CLI secrets into git

Current unknowns that should be validated before standardizing exact commands in repo automation:

- whether the preferred bootstrap flow should use a native age identity, an SSH host identity, or both
- whether the exact same host identity used for agenix recipients should also be reused for `gopass`
- how smooth mixed-recipient setups are in practice when combining host and YubiKey recipients
- which pinned `gopass` version should be treated as the supported baseline

Until that validation is done, treat `gopass` as a strong architectural fit, but keep version-specific command examples conservative.

### YubiKey Recipients For Gopass

Upstream `gopass` age support appears to include plugin identities such as `age-plugin-yubikey`, which means YubiKey-backed recipients are a plausible fit for local `gopass` stores.

That leads to three viable patterns:

- **YubiKey-only**: strongest operator-presence requirement, but highest day-to-day friction
- **Host-only**: best convenience for disposable host-local secrets, but weakest recovery story
- **Host + YubiKey recipients**: host convenience plus admin portability or recovery

Current recommendation:

- for disposable local CLI secrets, host-only or host-plus-YubiKey recipients are both reasonable
- for anything you may want to migrate, inspect, or recover outside the host, prefer host-plus-YubiKey recipients

This is still an area that should be validated with the exact `gopass` version you plan to standardize on.

---

## Threat Model

This proposal uses three classes of identities:

- admin identities that can decrypt all secrets
- machine identities that can decrypt only secrets explicitly assigned to that machine
- a break-glass recovery identity that can decrypt all secrets if admin hardware is unavailable

Security properties:

- secrets stay out of the Nix store
- facts remain free of secret material
- recipient scope can be narrowed per secret
- admin re-keying can remove future recipient access

Tradeoffs and limits:

- a host that can decrypt a secret at runtime must be treated as trusted for that secret
- compromise of a host implies compromise of every secret already decrypted by that host
- removing a compromised host from recipient lists does not revoke plaintext it already read
- using SSH host keys as recipients improves unattended operation but makes those host keys part of the secret trust boundary

That means `agenix -r` changes who can decrypt future ciphertext, but it does not by itself rotate the underlying secret value.

---

## Key Inventory

Four key types are used, each with a distinct role.

| Key | Type | Purpose | Decrypts |
|-----|------|---------|----------|
| Yubikey Primary | `age` via PIV | Day-to-day admin, re-keying | All secrets |
| Yubikey Spare | `age` via PIV | Offline admin backup | All secrets |
| Break-glass | `age` static key | Disaster recovery | All secrets |
| Host SSH Key | `ssh-ed25519` | Machine-local decryption where justified | Assigned host secrets only |

### Yubikey-backed Admin Keys

Use two Yubikey-backed age recipients generated with `age-plugin-yubikey`.

- **Primary Yubikey**: normal admin operations such as re-keying and adding secrets
- **Spare Yubikey**: stored securely offline and tested occasionally

Recommended practice:

- require touch confirmation
- keep the spare physically separate from the primary
- use admin identities for any operation that edits encrypted material or recipient sets

### Break-glass Static Key

Keep one static `age` keypair for disaster recovery if both Yubikeys are unavailable.

- store the encrypted private key in at least two physically separate locations
- protect it with a strong passphrase
- do not store the passphrase only in a password manager that depends on this same infrastructure
- treat any use of the break-glass key as a security event and review whether it needs replacement afterward

### Host SSH Keys

Host SSH keys are convenience recipients, not high-assurance administrative identities.

Use them only when the host genuinely needs unattended decryption.

- **NixOS**: justified for first boot, unattended rebuilds, and unattended reboots
- **nix-darwin**: acceptable if the machine should rebuild without an admin key present
- **standalone Home Manager**: prefer manual bootstrap with an explicit host key only when unattended decryption is actually useful

For this repo, extra manual key generation on darwin and standalone Home Manager is acceptable. That is preferable to pretending those platforms have the same unattended bootstrap requirements as NixOS.

---

## Recipient Strategy

Every secret should be encrypted to:

- all admin recipients: both Yubikeys plus the break-glass key
- only the host recipients that genuinely need that secret

Minimal exposure principle:

- a secret should exist on the fewest possible hosts, for the shortest necessary time, with the narrowest permissions that still satisfy the workflow

Principles:

- do not add every host to every secret
- keep machine-scoped secrets machine-scoped
- prefer per-host credentials over shared credentials when possible
- prefer the narrowest recipient list that still supports the required workflow

Illustrative example only:

```nix
# Example recipient inventory, not a current repo path.
let
  yubikey1 = "age1...";
  yubikey2 = "age1...";
  breakglass = "age1...";

  admin = [ yubikey1 yubikey2 breakglass ];

  hosts = {
    mbp = "ssh-ed25519 AAAA...";
    "alex@desktop" = "ssh-ed25519 AAAA...";
  };
in
{
  "example-token.age".publicKeys = admin ++ [ hosts.mbp ];
  "desktop-wifi.age".publicKeys = admin ++ [ hosts."alex@desktop" ];
}
```

This repo does not currently expose a canonical tracked `keys.nix` or `secrets/secrets.nix`. If such an inventory is added later, document the real path structure at that time rather than treating the example above as already implemented.

If secret-management automation is added later, expose it as a flake `app` or `package` rather than a standalone `scripts/*.sh` entrypoint.

### Re-keying Policy

Re-key when:

- adding a new recipient
- removing a retired recipient
- rotating a Yubikey
- replacing the break-glass key

Re-keying changes ciphertext recipients. It does **not** rotate the secret value itself.

Use:

```bash
agenix -r
```

Then review the encrypted changes and commit them if appropriate.

### Machine-Only Recipient Exceptions

`agenix` technically allows a secret to be encrypted only to a host recipient.

That should be treated as an exception policy, not a default.

Use host-only recipients only for secrets that are:

- disposable or easy to reissue
- truly host-local
- not required for admin recovery, migration, or incident response

Do not use host-only recipient sets for secrets that may need central recovery or operator inspection later.

If a host-only secret is lost with the machine, assume the secret itself must be recreated, not merely re-keyed.

---

## Host Onboarding Flow

Add a host to this repo first, then add secret recipients only where needed.

### 1. Add the Host Normally

Follow [`docs/adding-a-host.md`](./adding-a-host.md):

- add host metadata to `hosts/facts.nix`
- add the host composition root under `hosts/<name>/configuration.nix`
- keep facts and composition concerns separate

Examples already present in this repo include:

- `hosts/mbp/configuration.nix`
- `hosts/desktop/configuration.nix`

### 2. Decide Whether the Host Needs a Machine Recipient

Use a host SSH key recipient only if the machine should decrypt secrets without an admin key present.

- **NixOS**: usually yes
- **nix-darwin**: maybe
- **standalone Home Manager**: often no unless you want unattended user-level rebuilds

For API tokens and similar credentials, also decide whether the secret should be:

- per-host
- shared across a small set of machines
- admin-only with no machine recipient at all

### 3. Generate or Capture the Host Public Key

#### NixOS

For first-boot unattended decryption, pre-generate the host SSH keypair locally before installation.

```bash
mkdir -p hosts/<hostname>
ssh-keygen -t ed25519 -f hosts/<hostname>/ssh_host_ed25519_key -N "" -C "<hostname>"
```

If you use an SSH CA for host trust, sign the public key separately:

```bash
ssh-keygen -s ~/.ssh/ca_key -I <hostname> -h hosts/<hostname>/ssh_host_ed25519_key.pub
```

The CA signature is for SSH trust only. Agenix uses the raw public key.

#### nix-darwin and standalone Home Manager

Manual bootstrap is acceptable here, so use explicit manual key generation rather than relying on opportunistic key discovery.

Generate a dedicated SSH host key on the machine:

```bash
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -C "<hostname>"
```

Then record the public key in your secret recipient inventory.

For standalone Home Manager, only do this if you actually want machine-readable secrets for unattended use. Otherwise, keep secrets admin-decryptable only.

### 4. Add the Public Key to the Secret Recipient Inventory

Record the host public key in whatever recipient inventory structure you adopt, then add it only to the secrets that host needs.

Keep this inventory outside `hosts/facts.nix`.

### 5. Re-key the Affected Secrets

With a Yubikey present:

```bash
agenix -r
```

### 6. Wire Secret Declarations in Modules

Declare `age.secrets.*` in the appropriate module layer:

- reusable module when the secret contract is shared
- host module when the secret is host-specific

Do not place these declarations in `hosts/facts.nix`.

### 7. Deploy or Rebuild

#### NixOS

Install with the pre-generated host key injected as sensitive bootstrap material:

```bash
nix run .#install-host -- <hostname> root@<target-ip>
```

If `hosts/<hostname>/bootstrap-pre-kexec.sh` exists, the repo-local wrapper runs that script over SSH on the preinstall OS before invoking `nixos-anywhere`. This is intended for source-OS preparation such as temporary zram setup on low-memory VPS reinstalls; keep that hook free of durable secrets and treat it as repo-local operational bootstrap logic.

Equivalent expanded form:

```bash
nix run .#nixos-anywhere -- --flake ".#<hostname>" \
  --extra-files hosts/<hostname> \
  root@<target-ip>
```

Before touching a real target, you can preflight the host's install closure and disko layout with:

```bash
nix run .#install-host-vm-test -- <hostname>
```

If the pinned `disko` toolchain is currently blocking `system.build.installTest`, fall back to checking the host's `system.build.diskoScript` and `system.build.toplevel` evaluation paths until that upstream VM-test issue is fixed.

For the direct-boot installer flow, the live installer environment should import `nixosModules.installer-bootstrap-ssh` so the same operator keys can reach the machine before installation starts.

Set `aw1cks.provisioning.bootstrapAuthorizedKeys` explicitly for that installer environment rather than assuming the final host identity keys should also grant bootstrap root access.

Treat `hosts/<hostname>/ssh_host_ed25519_key` as a private key throughout this step.

- do not commit it
- do not leave unnecessary local copies behind after installation
- assume compromise if bootstrap artifacts are copied into places you do not control

If this repo later adds an enrollment helper for this flow, expose it through the flake so the supported interface is something like `nix run .#enroll-host -- <args>` rather than a raw `scripts/enroll-host.sh` path.

#### nix-darwin and standalone Home Manager

Once the machine's public key is in the recipient set and secrets are re-keyed, rebuild normally:

- `just rebuild` for the current darwin machine
- `just rebuild` for standalone Home Manager on non-NixOS Linux

---

## Platform Notes

### NixOS

NixOS is the strongest case for host SSH recipients because first boot and subsequent unattended activation are part of the desired workflow.

### nix-darwin

This repo already includes agenix in the shared darwin constructor. Host SSH recipients are acceptable here, but they are a convenience choice, not a requirement. Use them if you want local rebuilds to succeed without an admin key present.

### Standalone Home Manager

This repo's standalone Home Manager hosts are keyed by configuration names such as `"alex@desktop"` and derive shared metadata from `hosts/facts.nix`.

For this target, the least-privilege default is often:

- no machine recipient
- admin identities decrypt during intentional maintenance

Only add a host SSH recipient if unattended machine-local decryption is worth the added trust placed in that machine.

---

## Operational Procedures

### Routine Operations

- `nix build` and CI evaluation do not decrypt agenix payloads
- `agenix -r` requires an admin identity
- routine rebuild behavior depends on whether the target has a machine recipient for the required secrets

### Break-glass Procedure

If both Yubikeys are unavailable:

```bash
# Decrypt the break-glass private key
age --decrypt -i break-glass.age.enc break-glass.key

# Use it to decrypt a secret
agenix -i break-glass.key -d path/to/secret.age
```

Afterward:

- securely remove any temporary plaintext key material
- record that break-glass access was used
- decide whether the break-glass key must be replaced and all secrets re-keyed

### Runtime Exposure Note

Agenix keeps encrypted payloads out of the Nix store, but once a host decrypts a secret, that plaintext is still exposed to normal host-compromise risk, service-level leakage, and file-permission mistakes.

---

## Incident Response

Different incidents need different responses.

| Event | Re-key recipients? | Rotate secret values? | Notes |
|------|---------------------|-----------------------|-------|
| Planned host retirement | Yes | Usually no | Remove the host recipient from secrets it no longer needs |
| Yubikey replacement | Yes | No | Replace the old admin recipient and re-key |
| Suspected host compromise | Yes | Yes | Assume the host may have read every secret assigned to it |
| Suspected leaked bootstrap private key | Yes | Yes | Treat as host compromise if it protected decryptable secrets |
| Break-glass key exposure | Yes | Usually yes | Replace the recovery identity and review broad secret rotation |

The important distinction is:

- **re-keying** changes recipients for future ciphertext
- **rotating secret values** changes the secret itself after a likely disclosure

---

## Decryption Lifecycle

| Event | Key Used | Yubikey Needed? |
|-------|----------|-----------------|
| `nix build` / CI | None | No |
| `agenix -r` | Admin identity | Yes |
| NixOS first boot with pre-generated host key | Host SSH key | No |
| NixOS unattended reboot | Host SSH key | No |
| Darwin rebuild with host recipient configured | Host SSH key | No |
| Home Manager rebuild with no host recipient | Admin identity | Yes |
| Break-glass recovery | Static key + passphrase | No |

On NixOS, agenix-decrypted files are typically made available at runtime rather than through the Nix store. Do not assume Linux-specific runtime paths apply unchanged to darwin or standalone Home Manager.

---

## Encryption At Rest

There are three different questions to keep separate.

### 1. Encryption At Rest In Git

`agenix` handles this well.

- encrypted `.age` files are safe to commit
- recipient scope is explicit and reviewable
- the repository does not need plaintext secrets

### 2. Encryption At Rest On A Powered-Off Host

This is primarily a full-disk-encryption problem, not an `agenix` problem.

Recommended baseline:

- macOS: FileVault
- Linux: LUKS or equivalent full-disk encryption

This complements `agenix` by protecting secrets and bootstrap material if the device is lost or stolen while powered off.

### 3. Plaintext Exposure On A Running Host

If a host can use a secret unattended, that host can access the plaintext at runtime.

That means no architecture can simultaneously provide:

- unattended machine-local use
- and strong protection against the running host itself

Practical guidance:

- keep recipient scope narrow
- prefer per-host credentials
- keep file permissions tight
- avoid unnecessary persistence or broad environment exports
- rotate secrets quickly after suspected compromise

For especially sensitive workstation API keys, prefer process-local loading or tightly permissioned files rather than exporting them globally into every shell session.

---

## Suggested Inventory Layout

This repo does not currently ship a canonical secret inventory tree, but if one is added later, keep it separate from facts and host composition.

One reasonable layout would be:

```text
repo/
├── hosts/
│   ├── facts.nix
│   └── <hostname>/configuration.nix
├── modules/
│   ├── nixos/
│   ├── darwin/
│   └── home-manager/
└── secrets/
    ├── recipients.nix
    ├── secrets.nix
    └── *.age
```

If you adopt a layout like this, document it as the real implementation only after the files exist.

Any helper used to manage that inventory should be surfaced as a flake `app` or `package` so it is pinned, reproducible, and discoverable through the repository interface.

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `agenix` | Secret encryption, decryption, and module integration |
| `age` | Underlying encryption format |
| `age-plugin-yubikey` | Yubikey-backed admin identities |
| `nixos-anywhere` | NixOS installation workflow for pre-generated host key bootstrap |
