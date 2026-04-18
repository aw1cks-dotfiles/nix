{
  lib,
  inputs,
  config,
  ...
}:
{
  perSystem =
    { system, pkgs, ... }:
    lib.mkIf pkgs.stdenv.isLinux (
      let
        installerSystem = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
            config.flake.nixosModules.installer-bootstrap-ssh
            {
              networking.hostName = "installer";
              isoImage.appendToMenuLabel = " Dendritic";
              aw1cks.provisioning.bootstrapAuthorizedKeys = config.aw1cks.identity.selected.authorizedKeys;
            }
          ];
        };
      in
      {
        packages.installer-iso = installerSystem.config.system.build.isoImage;
      }
    );
}
