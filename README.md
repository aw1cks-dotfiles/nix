# nix

My Nix configuration.

## Platforms

- NixOS
- Generic Linux (home-manager)
- MacOS (nix-darwin)

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

Install the Nix daemon.

On Arch Linux: `sudo pacman -S nix`

For other distros:
```
$ sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
$ curl -L https://nixos.org/nix/install | sh
$ sudo systemctl enable --now nix-daemon
$
```

If running on a domain-joined machine, you may need to install `nscd`.

Ensure the user is in the `trusted-users` list to prevent annoying warnings:

```
$ echo "trusted-users = $(whoami)" | sudo tee -a /etc/nix/nix.conf
$ sudo systemctl restart nix-daemon
$
```

### Running home-manager for the current machine

The home-manager CLI is exposed as the default app for hosts which have `configurations.home` declared.

It can be invoked as such:

```
$ nix run . -- switch --flake .
$
```
