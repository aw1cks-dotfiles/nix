# Adding A Host

Add hosts in two places: `hosts/_facts.nix` for shared metadata and `hosts/<name>/configuration.nix` for repo-local composition.

## 1. Add Facts

Create a normalized entry in `hosts/_facts.nix`:

```nix
{
  my-host = {
    system = "aarch64-darwin";
    kind = "darwin";
    roles = [ "desktop" "interactive" ];
    user = "alex";
    homeDirectory = "/Users/alex";
    hostName = "my-host";
  };
}
```

For standalone Home Manager hosts, the facts key should match the configuration name and follow `user@host` or `user@host.domain`, such as `"alex@desktop"`.

Keep these out of facts:

- `module`
- embedded `home`
- local paths
- `nvidia.pinFile`
- secrets

## 2. Add The Composition Root

Create `hosts/<name>/configuration.nix` and declare the appropriate `configurations.*` entry.

Keep host declarations minimal. Constructors fill in shared user and home-directory metadata from `hosts/_facts.nix`, while host files keep local composition and any values that must still be declared explicitly:

```nix
{ ... }:
{
  configurations.darwin.my-host = {
    module = {
      system.stateVersion = 6;
    };
    home = {
      home.stateVersion = "25.11";
    };
  };
}
```

Do not manually import repeated role profiles in host files. Constructors already expand role-derived imports from the matching facts entry and fill in shared user metadata from facts.

For darwin hosts, constructors also default the top-level constructor `system`, `nixpkgs.hostPlatform`, and `networking.hostName` from shared facts, so hosts normally do not need to restate any of them unless they have an unusual override.

For standalone Home Manager hosts, constructors also default the top-level constructor `system`, plus `home.username` and `home.homeDirectory`, from facts, so host roots normally only need to keep host-local settings such as `home.stateVersion`.

For standalone Home Manager hosts, the `user` segment in the configuration attr name must match the resolved constructor user from facts or identity selection.

The current resolution rules come from `modules/constructors/*.nix`, `modules/constructors/_lib.nix`, and `modules/schema/identity.nix`.

## 3. Keep Local Concerns Local

These belong in the host composition root instead of facts:

- local file paths
- embedded `home` payloads
- NVIDIA enablement and `nvidia.pinFile`
- other constructor-specific toggles

## 4. Add Secrets Separately

If the host needs secrets:

- wire them through agenix
- add `age.secrets.*` declarations in the relevant module layer
- keep the encrypted files and secret values out of `hosts/_facts.nix`

## 5. Validate Narrowly

Before relying on flake evaluation, ensure any new Nix files are tracked by git.

Then run the narrowest useful validation for the affected constructor path, and use `nix flake check` when it meaningfully covers the change.
