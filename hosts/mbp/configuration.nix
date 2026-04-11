{ ... }:
{
  configurations.darwin.mbp = {
    system = "aarch64-darwin";
    module = {
      networking.hostName = "mbp";
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
