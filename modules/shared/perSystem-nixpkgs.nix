# Configure the flake-parts perSystem nixpkgs instance.
# This sets allowUnfree so that perSystem.packages entries (such as the
# repo-local omnissa-horizon-client) can be built via `nix build .#<pkg>`.
{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };
}
