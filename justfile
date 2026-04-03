default_flake_target := '.'

hm-switch target=default_flake_target:
  nix run . -- switch --flake {{target}}

update-flake:
  nix flake update
