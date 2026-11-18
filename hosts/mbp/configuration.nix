{ config, ... }:
{
  configurations.darwin.mbp = {
    module = {
      imports = [
        config.aw1cks.modules.darwin.tailscale-app
        config.aw1cks.modules.darwin.linux-builder
      ];
      services.tailscale-app.enable = true;
      nix.linux-builder.config = { lib, ... }: {
        # Merge with upstream's forced list without replacing the daemon key.
        services.openssh.authorizedKeysFiles = lib.mkForce [
          "/etc/ssh/authorized_keys.d/%u"
        ];
        users.users.builder.openssh.authorizedKeys.keys = config.aw1cks.identity.selected.authorizedKeys;
      };
      system.stateVersion = 6;
    };
    home = {
      imports = [
        config.aw1cks.modules.home.tailscale-serve
        config.aw1cks.modules.home.kata
        config.aw1cks.modules.home.colima
        config.aw1cks.modules.home.colimabar
      ];
      home.stateVersion = "25.11";
      modules.mpv.upscaling.enable = true;
      modules.ai.omp = {
        storage = "xdg";
        settings = {
          composer = {
            shape = "borderless";
            tokenRate = false;
          };
          display = {
            cacheMissMarker = true;
            showTurnTime = true;
            showTokenUsage = true;
            pinnedAgents = "full";
            shimmer = "kitt";
            subagentLivePreview = true;
          };
          statusLine = {
            preset = "nerd";
            contextLine = "embedded";
            separator = "none";
            transparent = true;
          };
          symbolPreset = "nerd";
          task.showResolvedModelBadge = true;
          tui = {
            completeScrollback = true;
            imeSafeCursor = true;
            resizeScrollback = "rebuild";
            titleSpinner = "pulse";
          };
          modelRoles.judge = "openrouter/perplexity/pplx-decider-v1.3:free";
          retry.fallbackChains.judge = [
            "openrouter/baseten/elephant-1"
            "openrouter/liquid/d1.1"
          ];
        };
      };
      modules.colima = {
        enable = true;
        mounts = [
          {
            location = "~/Documents/git";
            writable = true;
          }
        ];
      };
      modules.colimabar.enable = true;
      modules.learnharness.enable = true;
      modules.tern = {
        enable = true;
        settings = {
          agents.keep_tui = [
            "claude"
            "codex"
            "copilot"
          ];
          composer_text = "Markdown";
          cursor = {
            pulse = "ripple";
            smooth_blink = true;
            trail = "warp";
          };
          expand_thoughts = true;
          material = "Glass";
          surface_diffs = "Split";
          surface_fold = false;
          surface_tab_width = 4;
          theme_light = "oxocarbon-dark";
          widget_look = "outline";
        };
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
