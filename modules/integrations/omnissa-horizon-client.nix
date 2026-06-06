# Repo-local Omnissa Horizon packages.
#
# Exposes both the fixed classic client and the new .NET/Avalonia next client
# as flake outputs so downstream consumers and `nix build .#omnissa-horizon-client[-next]`
# both work. The overlay in modules/constructors/_lib.nix replaces the
# nixpkgs versions for every configured package set (NixOS, Home Manager).
{ inputs, lib, ... }:
let
  unfreePkgsFor =
    system:
    import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
in
{
  perSystem =
    { system, ... }:
    lib.optionalAttrs (system == "x86_64-linux") (
      let
        pkgs = unfreePkgsFor system;
      in
      {
        packages.omnissa-horizon-client =
          pkgs.callPackage ../../packages/omnissa-horizon-client/package.nix
            { };
        packages.omnissa-horizon-client-next =
          pkgs.callPackage ../../packages/omnissa-horizon-client/next.nix
            { };
      }
    );
}
