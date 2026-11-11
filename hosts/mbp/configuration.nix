{ config, ... }:
{
  configurations.darwin.mbp = {
    module = {
      imports = [ config.aw1cks.modules.darwin.tailscale-app ];
      services.tailscale-app.enable = true;
      system.stateVersion = 6;
    };
    home = { ... }: {
      imports = [
        config.aw1cks.modules.home.tailscale-serve
        config.aw1cks.modules.home.kata
      ];
      home.stateVersion = "25.11";
      modules.tern = {
        enable = true;
        plugins = {
          tern-projects.enable = true;
          tern-kata.enable = true;
          tern-kube.enable = true;
          tern-grafana.enable = true;
        };
      };
      services.kata.enable = true;
      services.tern = {
        daemon.enable = true;
        remote = {
          enable = true;
          listenAddress = "0.0.0.0";
        };
      };
      services.tailscale-serve = {
        enable = true;
      };
    };
  };
}
