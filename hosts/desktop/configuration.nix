{ ... }:
{
  configurations.home."alex@desktop" = {
    system = "x86_64-linux";
    nvidia = {
      enable = true;
      pinFile = ./nvidia.json;
    };
    module = {
      modules.lazyvim.enable = true;
      home = {
        stateVersion = "25.05";
      };
    };
  };
}
