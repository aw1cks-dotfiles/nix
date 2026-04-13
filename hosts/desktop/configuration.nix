{ ... }:
{
  configurations.home."alex@desktop" = {
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
