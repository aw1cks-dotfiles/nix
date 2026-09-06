{ inputs, lib, ... }:
{
  aw1cks.modules.home.zed =
    { config, pkgs, ... }:
    let
      ompCommand = "${config.programs.omp.package}/bin/omp";
      zedPackage = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.zed-editor;
    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "zed" ''
          exec zeditor "$@"
        '')
      ];

      programs.zed-editor = {
        enable = true;
        defaultEditor = false;
        # Zed 1.3.6 accepts agent.terminal_init_command in settings.json but
        # cannot execute it or discover current ChatGPT subscription models.
        package = zedPackage;

        # Make repository-relevant Nix tooling available even when Zed is
        # launched from a graphical session with a limited shell PATH.
        extraPackages = [
          pkgs.alejandra
          pkgs.nixd
          pkgs.statix
        ];

        extensions = [
          "nix"
          "dockerfile"
          "terraform"
          "helm"
          "toml"
          "csharp"
          "kotlin"
          "sql"
          "mermaid"
          "oxocarbon"
        ];

        userSettings = lib.mkMerge [
          {
            vim_mode = true;
            relative_line_numbers = "enabled";

            # Match the current Neovim policy: formatting remains explicit.
            format_on_save = "off";
            hard_tabs = false;
            tab_size = 4;

            buffer_font_family = "CaskaydiaMono Nerd Font";
            ui_font_family = "SF Pro Display Nerd Font";
            terminal.font_family = "CaskaydiaMono Nerd Font";

            theme = "Oxocarbon Dark (IBM Carbon)";

            languages = {
              Nix = {
                tab_size = 2;
                language_servers = [
                  "nixd"
                  "!nil"
                ];
                formatter = {
                  external = {
                    command = "${pkgs.alejandra}/bin/alejandra";
                    arguments = [
                      "--quiet"
                      "--"
                    ];
                  };
                };
              };
              Lua.tab_size = 2;
              Python.tab_size = 4;
            };

            lsp.nixd.binary.path = "${pkgs.nixd}/bin/nixd";
          }

          (lib.mkIf config.programs.omp.enable {
            agent_servers.omp = {
              type = "custom";
              command = ompCommand;
              args = [ "acp" ];
              env = { };
            };

            agent = {
              terminal_init_command = ompCommand;
              notify_when_agent_waiting = "primary_screen";
              play_sound_when_agent_done = "always";
            };
          })
        ];

        userKeymaps = [
          {
            context = "Editor && vim_mode == normal";
            bindings = {
              "space f f" = "file_finder::Toggle";
              "space e" = "project_panel::ToggleFocus";
              "space g g" = "git_panel::ToggleFocus";
              "space a a" = "agent::ToggleFocus";
              "space t t" = "workspace::NewTerminal";
              "space x x" = "diagnostics::Deploy";
              "space s s" = "project_symbols::Toggle";
              "space c s" = "outline_panel::ToggleFocus";
            };
          }
        ];
      };
    };
}
