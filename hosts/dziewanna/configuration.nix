{ ... }:
{
  configurations.nixos.dziewanna = {
    module = {
      imports = [
        ./hardware-configuration.nix
        ./disko.nix
      ];

      system.stateVersion = "25.05";
    };
  };
}
