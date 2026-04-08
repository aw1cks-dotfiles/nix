# nix

Reusable Nix library plus public live host configurations for NixOS, standalone Home Manager, and nix-darwin.

## Platforms

- NixOS
- Generic Linux (home-manager)
- macOS (nix-darwin)

## Patterns used in this repository

- [flake-parts](https://flake.parts) is used throughout
- The [dendritic pattern](https://github.com/mightyiam/dendritic) is followed; each Nix file is a standalone flake-parts module
- The main [`flake.nix`](./flake.nix) is generated using [flake-file](http://github.com/vic/flake-file)
- [import-tree](https://github.com/vic/import-tree) is used within the [modules](./modules/flake-modules.nix)
    - All Nix files in the path are recursively imported, except for any path beginning with `_`, e.g. [`_lib`](./modules/_lib)
    - [Hosts](./modules/hosts/) themselves are also modules. These import other modules, which are groups of configuration the host opts into.
    - All modules are [outputs](./outputs.nix) of the flake, so that they can be consumed from other flakes.
- Secrets are managed with [agenix](https://github.com/ryantm/agenix)
- TODO: Adopt [den](https://github.com/vic/den) to create aspect-based groupings of modules

## Deploying

### Prerequisites

Install a standard multi-user Nix daemon. For nix-darwin hosts, prefer the standard Nix installer over Determinate if you want nix-darwin to manage the Nix installation.

On Arch Linux: `sudo pacman -S nix`

For other distros:

```sh
sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
curl -L https://nixos.org/nix/install | sh
sudo systemctl enable --now nix-daemon
```

If running on a domain-joined machine, you may need to install `nscd`.

Ensure the user is in the `trusted-users` list to prevent annoying warnings:

```sh
echo "trusted-users = $(whoami)" | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon
```

### Bootstrap note

If you are bootstrapping on a machine where `nix` does not yet have flakes enabled, run commands with:

```sh
NIX_CONFIG='experimental-features = nix-command flakes'
```

This is mainly needed for first-run bootstrapping before this repo's own Nix settings are active.

### Rebuilding the current machine

The pinned `nh` CLI is exposed as a flake app on all supported platforms.

Bootstrap rebuilds can be run directly with:

```sh
NIX_CONFIG='experimental-features = nix-command flakes' nix run .#nh -- darwin switch .
NIX_CONFIG='experimental-features = nix-command flakes' nix run .#nh -- os switch .
NIX_CONFIG='experimental-features = nix-command flakes' nix run .#nh -- home switch .
```

Once `just` is available, `just rebuild` wraps the same pinned `nh` entrypoint:

- nix-darwin: `just rebuild`
- NixOS: `just rebuild`
- standalone Home Manager on non-NixOS Linux: `just rebuild`

### Running pinned frontends directly

This flake exposes pinned app entrypoints for the shared frontends:

- `nix run .#nh -- ...`
- `nix run .#darwin -- ...`
- `nix run .#home-manager -- ...`

For example:

```sh
nix run .#nh -- home switch .
nix run .#home-manager -- switch --flake .
```

### Home Manager NVIDIA schema

Standalone Home Manager Linux hosts can opt into the shared NVIDIA contract at the top level of `configurations.home.<name>`:

```nix
{
  system = "x86_64-linux";
  nvidia = {
    enable = true;
    pinFile = ./nvidia.json;
  };
  module = {
    imports = [
      profiles.home.base
      profiles.home.developer
      profiles.home.desktop
    ];

    home = {
      username = "alex";
      homeDirectory = "/home/alex";
      stateVersion = "25.05";
    };
  };
}
```

When `nvidia.enable = true`, the shared Home Manager layer automatically enables `targets.genericLinux` and wires `targets.genericLinux.gpu.nvidia` from the pin file.

Pin files are stored as JSON. NVIDIA-enabled Home Manager hosts must set `nvidia.pinFile` explicitly, typically to a host-local path such as `./nvidia.json`.

The JSON file must contain:

```json
{
  "version": "595.58.03",
  "sha256": "sha256-jA1Plnt5MsSrVxQnKu6BAzkrCnAskq+lVRdtNiBYKfk="
}
```

This metadata is also exposed as `homeNvidiaConfigurations` for updater tooling.

### Updating NVIDIA pins

Use the packaged updater to refresh the version and installer hash for the current machine:

```sh
nix run .#update-nvidia-version
```

For a remote target, pass the version and short hostname explicitly:

```sh
nix run .#update-nvidia-version -- 595.58.03 desktop
```

The updater rewrites the configured JSON pin file directly and no longer edits host Nix modules in place.

### Darwin host schema

Darwin hosts in `configurations.darwin` currently use this top-level shape:

```nix
{
  system = "aarch64-darwin";
  user = "alex";
  homeDirectory = "/Users/alex";
  module = {
    networking.hostName = "mbp";
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
  };
  home = {
    imports = [
      profiles.home.base
      profiles.home.developer
      profiles.home.desktop
    ];

    home.stateVersion = "25.11";
  };
}
```

The shared darwin layer derives `system.primaryUser`, `users.users.<name>.home`, `home-manager.users.<name>.home.username`, and `home-manager.users.<name>.home.homeDirectory` from `user` and `homeDirectory`.
