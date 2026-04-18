{ ... }:
{
  configurations.nixos.dziewanna = {
    module = {
      imports = [
        ./hardware-configuration.nix
        ./disko.nix
        ./network.nix
        ./acme.nix
        ./murmur.nix
      ];

      system.stateVersion = "25.05";
    };
  };
}
