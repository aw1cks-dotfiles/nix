# dziewanna

FIXME: we need to make the `bootloader` module more flexible
FIXME: we need to make sure that the test VMs work with legacy boot

```console
$ nix run github:nix-community/nixos-anywhere -- --flake .#dziewanna --target-host root@z5zkyafh.srv.binaryracks.net --build-on local --debug --show-trace --print-build-logs --no-disko-deps
$
```

This machine is very memory restricted so we need to do a bit of a hack.

While `nixos-anywhere` is running, we SSH to the NixOS live environment.

Once the disk gets created to `/mnt`, run `fallocate -l 2G /mnt/swapfile && chmod 600 /mnt/swapfile && mkswap /mnt/swapfile && swapon /mnt/swapfile`

TODO: come up with a proper way of doing this.
