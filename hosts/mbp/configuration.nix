{ ... }:
{
  configurations.darwin.mbp = {
    module = {
      system.stateVersion = 6;
    };
    home = {
      modules.lazyvim.enable = true;
      home = {
        stateVersion = "25.11";
      };
    };
  };
}
