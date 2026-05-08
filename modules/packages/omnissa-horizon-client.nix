# Repo-local Omnissa Horizon packages.
# Exposes both the fixed classic client and the new .NET/Avalonia next client
# as flake outputs. The overlay in modules/constructors/_lib.nix replaces the
# nixpkgs versions for all configured package sets (NixOS, Home Manager).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.omnissa-horizon-client =
        pkgs.callPackage ../../packages/omnissa-horizon-client/package.nix
          { };
      packages.omnissa-horizon-client-next =
        pkgs.callPackage ../../packages/omnissa-horizon-client/next.nix
          { };
    };
}
