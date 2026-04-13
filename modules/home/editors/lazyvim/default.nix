{ inputs, lib, ... }:
{
  aw1cks.modules.home.lazyvim =
    { config, pkgs, ... }:
    let
      cfg = config.modules.lazyvim;
      inherit (cfg) configDir;
      configDirString = toString configDir;
      sqliteLibraryPath = lib.makeLibraryPath [ pkgs.sqlite ];
      mermaidRendererPackage = import ../../dev/_mermaid.nix {
        inherit inputs lib;
      } pkgs;
      mmdrLightConfig = ./files/mmdr-light.json;
      mmdrDarkConfig = ./files/mmdr-dark.json;
      mmdcScript = pkgs.replaceVars ./files/mmdc.sh {
        mmdrBin = "${mermaidRendererPackage}/bin/mmdr";
        inherit mmdrDarkConfig mmdrLightConfig;
      };
      mmdcWrapper = pkgs.writeShellApplication {
        name = "mmdc";
        runtimeInputs = [
          mermaidRendererPackage
          pkgs.gawk
        ];
        text = ''
          exec ${pkgs.runtimeShell} ${mmdcScript} "$@"
        '';
      };
      ftpluginFiles = builtins.filter (
        file:
        let
          relativePath = lib.removePrefix "${configDirString}/" (toString file);
        in
        lib.hasPrefix "ftplugin/" relativePath && lib.hasSuffix ".lua" relativePath
      ) (lib.filesystem.listFilesRecursive configDir);
      queryFiles = builtins.filter (
        file:
        let
          relativePath = lib.removePrefix "${configDirString}/" (toString file);
        in
        lib.hasPrefix "queries/" relativePath && lib.hasSuffix ".scm" relativePath
      ) (lib.filesystem.listFilesRecursive configDir);
      ftpluginLinks = lib.listToAttrs (
        map (
          file:
          let
            relativePath = lib.removePrefix "${configDirString}/" (toString file);
          in
          lib.nameValuePair "${cfg.appName}/${relativePath}" { source = file; }
        ) ftpluginFiles
      );
      queryLinks = lib.listToAttrs (
        map (
          file:
          let
            relativePath = lib.removePrefix "${configDirString}/" (toString file);
          in
          lib.nameValuePair "${cfg.appName}/${relativePath}" { source = file; }
        ) queryFiles
      );
      lazyvimWrapper = pkgs.writeShellApplication {
        name = cfg.commandName;
        text = ''
          export NVIM_APPNAME="${cfg.appName}"
          ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            export LD_LIBRARY_PATH="${sqliteLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          ''}
          ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            export DYLD_FALLBACK_LIBRARY_PATH="${sqliteLibraryPath}''${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
          ''}
          exec -a "${cfg.commandName}" "${config.programs.neovim.finalPackage}/bin/nvim" "$@"
        '';
      };
    in
    {
      imports = [ inputs.lazyvim-nix.homeManagerModules.default ];

      options.modules.lazyvim = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable the repo-provided LazyVim migration behind a separate command.
            The shipped config is intentionally personal but can be replaced by
            overriding this module's options.
          '';
        };

        appName = lib.mkOption {
          type = lib.types.str;
          default = "lazyvim";
          description = "NVIM_APPNAME namespace used for the migrated LazyVim configuration.";
        };

        commandName = lib.mkOption {
          type = lib.types.str;
          default = "lazyvim";
          description = "Wrapper command name for the migrated LazyVim configuration.";
        };

        configDir = lib.mkOption {
          type = lib.types.path;
          default = ./files;
          description = ''
            Repo-provided LazyVim configuration directory. Override this to swap
            in a different config tree while keeping the wrapped command setup.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.appName != "nvim";
            message = "modules.lazyvim.appName must stay distinct from the default nvim app namespace.";
          }
          {
            assertion = cfg.commandName != "nvim";
            message = "modules.lazyvim.commandName must stay distinct from the default nvim command.";
          }
        ];

        programs.lazyvim = {
          enable = true;
          inherit (cfg) appName;
          configFiles = configDir;
          pluginSource = "latest";

          extras = {
            ai.copilot.enable = true;
            coding."mini-surround".enable = true;
            editor = {
              navic.enable = true;
              outline.enable = true;
            };
            lang = {
              docker = {
                enable = true;
                installDependencies = true;
              };
              dotnet.enable = true;
              git.enable = true;
              go = {
                enable = true;
                installDependencies = true;
              };
              helm = {
                enable = true;
                installDependencies = true;
              };
              json.enable = true;
              kotlin = {
                enable = true;
                installDependencies = true;
              };
              markdown = {
                enable = true;
                installDependencies = true;
              };
              nix.enable = false;
              python.enable = true;
              rust = {
                enable = true;
                installDependencies = true;
              };
              sql = {
                enable = true;
                installDependencies = true;
              };
              terraform = {
                enable = true;
                installDependencies = true;
              };
              toml = {
                enable = true;
                installDependencies = true;
              };
              yaml.enable = true;
            };
            util = {
              gh.enable = true;
              gitui = {
                enable = true;
                installDependencies = true;
              };
              octo.enable = true;
            };
          };

          extraPackages = with pkgs; [
            alejandra
            bacon
            docker-compose-language-service
            dockerfile-language-server
            cargo
            curl
            fd
            dotnet-sdk
            fsautocomplete
            fzf
            findutils
            gh
            git
            go
            golangci-lint
            gopls
            gofumpt
            gomodifytags
            gradle
            gnused
            gnutar
            hadolint
            helm-ls
            impl
            imagemagick
            jq
            ktlint
            kotlin-language-server
            lazygit
            lua-language-server
            markdown-toc
            markdownlint-cli2
            marksman
            mmdcWrapper
            mercurial
            nixd
            nodejs
            omnisharp-roslyn
            python3
            python3Packages.ruff
            ripgrep
            rust-analyzer
            rustc
            shellcheck
            shfmt
            sqlite
            sqlfluff
            statix
            stylua
            taplo
            tectonic
            terraform
            terraform-ls
            trash-cli
            tflint
            tree-sitter
            mermaidRendererPackage
            stdenv.cc
            ty
            vscode-langservers-extracted
            xclip
            yaml-language-server
          ];

          treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
            cpp
            c_sharp
            css
            dockerfile
            git_config
            git_rebase
            gitattributes
            gitcommit
            gitignore
            gotmpl
            groovy
            hcl
            jq
            kotlin
            latex
            make
            mermaid
            nix
            perl
            ruby
            scss
            sql
            svelte
            terraform
            typst
            vue
            xml
          ];
        };

        home.packages = [ lazyvimWrapper ];
        xdg.configFile = ftpluginLinks // queryLinks;
      };
    };
}
