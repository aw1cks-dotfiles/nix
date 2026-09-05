{ inputs, lib, ... }:
{
  aw1cks.modules.home.neovim =
    { config, pkgs, ... }:
    let
      configDir = ./files;
      configDirString = toString configDir;
      mermaidRendererPackage =
        inputs.mermaid-rs-renderer.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
      ompAcpConfig = pkgs.writeText "omp-avante-acp.yml" ''
        tools:
          approval:
            bash: allow
      '';
      avanteConfig = pkgs.replaceVars ./files/plugins/avante.lua {
        omp = "${config.programs.omp.package}/bin/omp";
        ompAcpConfig = ompAcpConfig;
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
          lib.nameValuePair "nvim/${relativePath}" { source = file; }
        ) ftpluginFiles
      );
      queryLinks = lib.listToAttrs (
        map (
          file:
          let
            relativePath = lib.removePrefix "${configDirString}/" (toString file);
          in
          lib.nameValuePair "nvim/${relativePath}" { source = file; }
        ) queryFiles
      );
    in
    {
      imports = [ (import ../../../_internal/neovim/lazyvim-nix-module.nix { inherit inputs; }) ];

      config = {
        programs.neovim = {
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
        };

        home.sessionVariables = {
          # We use an absolute path for SUDO_EDITOR.
          # home-manager hosts will not have the nix PATH setup and silently fall back.
          # NOTE: this can go stale when a new HM generation is built.
          # TODO: add a guard condition to avoid this for darwin/nixos
          SUDO_EDITOR = "${config.programs.neovim.finalPackage}/bin/nvim";
          VISUAL = "nvim";
        };

        programs.lazyvim = {
          enable = true;
          appName = "nvim";
          configFiles = configDir;
          pluginSource = "latest";

          extras = {
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

        xdg.configFile =
          ftpluginLinks
          // queryLinks
          // {
            "nvim/lua/plugins/avante.lua".source = lib.mkForce avanteConfig;
          };
      };
    };
}
