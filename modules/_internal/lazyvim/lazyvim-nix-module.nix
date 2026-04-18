{
  inputs,
  self ? null,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  lazyvimNixPath = inputs.lazyvim-nix + "/nix";

  dataLib = import (lazyvimNixPath + "/lib/data-loading.nix") { inherit lib pkgs; };
  pluginLib = import (lazyvimNixPath + "/lib/plugin-resolution.nix") {
    inherit lib pkgs;
    pluginMappings = dataLib.pluginMappings;
    ignoreBuildNotifications = cfg.ignoreBuildNotifications;
  };
  devPathLib = import (lazyvimNixPath + "/lib/dev-path.nix") {
    inherit lib pkgs;
    pluginMappings = dataLib.pluginMappings;
  };
  treesitterLib = import (lazyvimNixPath + "/lib/treesitter.nix") {
    inherit lib pkgs;
    treesitterMappings = dataLib.treesitterMappings;
    extractLang = dataLib.extractLang;
    ignoreBuildNotifications = cfg.ignoreBuildNotifications;
  };
  dependenciesLib = import (lazyvimNixPath + "/lib/dependencies.nix") {
    inherit lib pkgs;
    dependencies = dataLib.dependencies;
    ignoreBuildNotifications = cfg.ignoreBuildNotifications;
  };
  configLib = import (lazyvimNixPath + "/lib/config-generation.nix") { inherit lib; };
  fileLib = import (lazyvimNixPath + "/lib/file-scanning.nix") { inherit lib pkgs config; };

  cfg = config.programs.lazyvim;

  getEnabledExtras =
    extrasConfig:
    let
      processCategory =
        categoryName: categoryExtras:
        let
          enabledInCategory = lib.filterAttrs (
            extraName: extraConfig: extraConfig.enable or false
          ) categoryExtras;
        in
        lib.mapAttrsToList (
          extraName: extraConfig:
          let
            normalizedName = builtins.replaceStrings [ "-" ] [ "_" ] extraName;
            metadata = dataLib.extrasMetadata.${categoryName}.${normalizedName} or null;
          in
          if metadata != null then
            {
              inherit (metadata) name category import;
              config = extraConfig.config or "";
              hasConfig = (extraConfig.config or "") != "";
            }
          else
            null
        ) enabledInCategory;

      allCategories = lib.mapAttrsToList processCategory extrasConfig;
      flattenedExtras = lib.flatten allCategories;
      validExtras = lib.filter (x: x != null) flattenedExtras;
    in
    validExtras;

  enabledExtras = if cfg.enable then getEnabledExtras (cfg.extras or { }) else [ ];
  enabledExtraNames = map (extra: "${extra.category}.${extra.name}") enabledExtras;
  automaticTreesitterParsers = treesitterLib.automaticTreesitterParsers cfg enabledExtraNames;
  systemPackages = dependenciesLib.systemPackages cfg enabledExtraNames;

  # Avoid build-at-eval scanner work when the config is already provided as a
  # Nix path. That scanner only exists to discover unmanaged user plugin files
  # from a live home directory, which breaks cross-platform flake evaluation.
  userPlugins =
    if cfg.enable && cfg.configFiles == null then
      fileLib.scanUserPlugins "${config.home.homeDirectory}/.config/${cfg.appName}"
    else
      [ ];

  corePlugins = builtins.filter (p: p.is_core or false) (dataLib.pluginData.plugins or [ ]);

  extrasPlugins =
    let
      enabledExtrasFiles = map (extra: "extras.${extra.category}.${extra.name}") enabledExtras;
      isExtraEnabled = plugin: builtins.elem (plugin.source_file or "") enabledExtrasFiles;
      allExtrasPlugins = builtins.filter (p: !(p.is_core or false)) (dataLib.pluginData.plugins or [ ]);
    in
    builtins.filter isExtraEnabled allExtrasPlugins;

  allPluginSpecs = corePlugins ++ extrasPlugins ++ userPlugins;
  resolvedPlugins = map (pluginLib.resolvePlugin cfg) allPluginSpecs;

  resolvedTreesitterPlugin =
    let
      tsPlugins = lib.zipListsWith (
        spec: plugin: if spec.name == "nvim-treesitter/nvim-treesitter" then plugin else null
      ) allPluginSpecs resolvedPlugins;
      found = lib.findFirst (p: p != null) null tsPlugins;
    in
    if found != null then found else pkgs.vimPlugins.nvim-treesitter;

  devPath = devPathLib.createDevPath allPluginSpecs resolvedPlugins;
  availableDevSpecs = devPathLib.generateDevPluginSpecs devPathLib allPluginSpecs resolvedPlugins;
  extrasImportSpecs = configLib.extrasImportSpecs enabledExtras;
  treesitterGrammars =
    if cfg.pluginSource == "latest" then
      treesitterLib.treesitterGrammarsFromSource automaticTreesitterParsers
    else
      treesitterLib.treesitterGrammars automaticTreesitterParsers;

  filteredQueries = pkgs.runCommand "treesitter-queries" { } ''
    mkdir -p $out
    querySrc="${resolvedTreesitterPlugin}/runtime/queries"
    parserDir="${treesitterGrammars}/parser"

    for parser_so in "$parserDir"/*.so; do
      lang="$(basename "$parser_so" .so)"
      if [ -d "$querySrc/$lang" ]; then
        ln -s "$querySrc/$lang" "$out/$lang"
      fi
    done

    changed=1
    while [ "$changed" -eq 1 ]; do
      changed=0
      for linked_dir in "$out"/*/; do
        [ -d "$linked_dir" ] || continue
        for scm in "$linked_dir"/*.scm; do
          [ -f "$scm" ] || continue
          while IFS= read -r inherit; do
            if [ -n "$inherit" ] && [ -d "$querySrc/$inherit" ] && [ ! -e "$out/$inherit" ]; then
              ln -s "$querySrc/$inherit" "$out/$inherit"
              changed=1
            fi
          done < <(grep '^; inherits:' "$scm" | sed 's/^; inherits: *//' | tr ',' '\n' | tr -d ' ')
        done
      done
    done
  '';

  lazyConfig = configLib.lazyConfig {
    starterLua = dataLib.starterLua;
    starterVersion = dataLib.starterVersion;
    inherit devPath extrasImportSpecs availableDevSpecs;
  };

  extrasConfigFiles = configLib.extrasConfigFiles enabledExtras cfg.appName;
  scannedFiles = fileLib.scanConfigFiles cfg.configFiles cfg.appName;
  conflictChecks = fileLib.detectConflicts cfg scannedFiles;
  _ = if cfg.enable then conflictChecks else null;
in
{
  options.programs.lazyvim = import (lazyvimNixPath + "/options.nix") { inherit lib; };

  config = mkIf cfg.enable {
    _module.args._conflictCheck = conflictChecks;

    programs.neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;

      withNodeJs = true;
      withPython3 = true;
      withRuby = false;

      extraPackages = cfg.extraPackages ++ systemPackages;
      plugins = [ pkgs.vimPlugins.lazy-nvim ];
    };

    xdg.dataFile = {
      "${cfg.appName}/site/parser" = mkIf (automaticTreesitterParsers != [ ]) {
        source = "${treesitterGrammars}/parser";
      };
      "${cfg.appName}/site/queries" = mkIf (automaticTreesitterParsers != [ ]) {
        source = "${filteredQueries}";
      };
    };

    xdg.configFile = {
      "${cfg.appName}/init.lua".text = lazyConfig;

      "${cfg.appName}/lua/config/autocmds.lua" =
        mkIf (scannedFiles.configFiles ? autocmds || cfg.config.autocmds != "")
          (
            if scannedFiles.configFiles ? autocmds then
              { source = scannedFiles.configFiles.autocmds.file; }
            else
              {
                text = ''
                  -- User autocmds configured via Nix
                  ${cfg.config.autocmds}
                '';
              }
          );

      "${cfg.appName}/lua/config/keymaps.lua" =
        mkIf (scannedFiles.configFiles ? keymaps || cfg.config.keymaps != "")
          (
            if scannedFiles.configFiles ? keymaps then
              { source = scannedFiles.configFiles.keymaps.file; }
            else
              {
                text = ''
                  -- User keymaps configured via Nix
                  ${cfg.config.keymaps}
                '';
              }
          );

      "${cfg.appName}/lua/config/options.lua" =
        mkIf (scannedFiles.configFiles ? options || cfg.config.options != "")
          (
            if scannedFiles.configFiles ? options then
              { source = scannedFiles.configFiles.options.file; }
            else
              {
                text = ''
                  -- User options configured via Nix
                  ${cfg.config.options}
                '';
              }
          );

    }
    // (lib.mapAttrs' (
      name: content:
      lib.nameValuePair "${cfg.appName}/lua/plugins/${name}.lua" {
        text = ''
          -- Plugin configuration for ${name} (configured via Nix)
          ${content}
        '';
      }
    ) cfg.plugins)
    // (lib.mapAttrs' (
      name: fileInfo:
      lib.nameValuePair fileInfo.targetPath {
        source = fileInfo.file;
      }
    ) scannedFiles.pluginFiles)
    // extrasConfigFiles
    // (
      let
        hasUserPlugins = cfg.plugins != { } || scannedFiles.pluginFiles != { };
      in
      optionalAttrs (!hasUserPlugins) {
        "${cfg.appName}/lua/plugins/_lazyvim_nix_default.lua" = {
          text = ''
            -- Default plugin specification to ensure plugins directory is valid
            -- This prevents "No specs found for module 'plugins'" error
            return {}
          '';
        };
      }
    )
    // {
      "${cfg.appName}/lua/plugins/_lazyvim_nix_healthcheck.lua" = {
        text = ''
          -- [NIX] Disable treesitter healthcheck - parsers are pre-built by Nix
          vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            once = true,
            callback = function()
              local ok, ts = pcall(require, "lazyvim.util.treesitter")
              if ok and ts then
                ts.check = function()
                  return true, { ["nix"] = true }
                end
              end
            end,
          })
          return {}
        '';
      };
    };
  };
}
