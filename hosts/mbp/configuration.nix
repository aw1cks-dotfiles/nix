{ ... }:
{
  configurations.darwin.mbp = {
    system = "aarch64-darwin";
    module = {
      networking.hostName = "mbp";
      system.stateVersion = 6;
    };
    home = {
      home = {
        stateVersion = "25.11";
      };
    };
  };
}
