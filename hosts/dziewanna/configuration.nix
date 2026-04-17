{ ... }:
{
  configurations.nixos.dziewanna = {
    module = {
      imports = [
        ./hardware-configuration.nix
        ./disko.nix
        ./network.nix
      ];

      system.stateVersion = "25.05";
    };
  };
}
