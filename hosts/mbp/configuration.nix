{ config, ... }:
{
  configurations.darwin.mbp = {
    module = {
      imports = [ config.aw1cks.modules.darwin.tailscale-app ];
      services.tailscale-app.enable = true;
      system.stateVersion = 6;
    };
    home = { ... }: {
      home.stateVersion = "25.11";
      modules.ai.omp.collab.enable = true;
      modules.ai.paseo.enable = true;
      services.tailscale-serve = {
        enable = true;
      };
    };
  };
}
