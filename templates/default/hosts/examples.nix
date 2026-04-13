{ config, ... }:
{
  # Example layered downstream settings:
  # org.domain = "corp.example.internal";
  # org.ssl.enable = true;
  # org.ssl.extraCertificateFiles = [ ./certificates/internal-root-ca.crt ];

  # Standalone Home Manager example:
  # configurations.home."${config.aw1cks.identity.selected.username}@laptop" = {
  #   nvidia = {
  #     enable = true;
  #     pinFile = ./laptop/nvidia.json;
  #   };
  #   module = {
  #     imports = [
  #       config.org.profiles.home.work
  #     ];
  #
  #     modules.lazyvim.enable = true;
  #
  #     home.stateVersion = "25.11";
  #   };
  # };

  # NixOS with embedded Home Manager example:
  # configurations.nixos.workstation = {
  #   module = {
  #     imports = [ ];
  #
  #     system.stateVersion = "25.11";
  #   };
  #   home = {
  #     imports = [
  #       config.org.profiles.home.work
  #     ];
  #
  #     modules.lazyvim.enable = true;
  #     home.stateVersion = "25.11";
  #   };
  # };
}
