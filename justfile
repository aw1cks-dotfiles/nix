default_flake_target := '.'

hm-switch target=default_flake_target:
  nix run . -- switch --flake {{target}}

update-flake:
  nix flake update

clean:
  nix profile wipe-history --older-than 7d
  nix store gc
  nix store optimise
