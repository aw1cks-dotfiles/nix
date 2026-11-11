{ config, ... }:
{
  configurations.darwin.mbp = {
    module = {
      imports = [ config.aw1cks.modules.darwin.tailscale-app ];
      services.tailscale-app.enable = true;
      system.stateVersion = 6;
    };
    home = { ... }: {
      imports = [ config.aw1cks.modules.home.tailscale-serve ];
      home.stateVersion = "25.11";
      modules.tern.enable = true;
      services.tern = {
        daemon.enable = true;
        remote.enable = true;
      };
      services.tailscale-serve = {
        enable = true;
      };
    };
  };
}
