# nix

Basic nix configuration with home-manager, at the moment this just installs some packages.

## Setup

Make sure to source the envvars in shell profile, e.g.

```
[ -f "${HOME}/.nix-profile/etc/profile.d/hm-session-vars.sh" ] && source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
```

### Arch Linux

```console
$ sudo pacman -S nix
$ sudo usermod -aG nix alex
$ mkdir -pv ~/.config/nix
$ echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf
$ mkdir -pv ~/.config/nixpkgs
$ echo '{
  allowUnfree = true;
}' > ~/.config/nixpkgs/config.nix
$ sudo systemctl enable --now nix-daemon
$ nix-channel --add https://nixos.org/channels/nixos-25.05 nixpkgs
$ nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz home-manager
$ nix-channel --update
$ nix-shell '<home-manager>' -A install
$ make
```
