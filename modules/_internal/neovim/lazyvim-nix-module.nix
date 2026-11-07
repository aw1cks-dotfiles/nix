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
  fileLib = import (lazyvimNixPath + "/lib/file-scanning.nix") { inherit lib; };

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

  scanPluginDirectory =
    pluginsDir:
    if !builtins.pathExists pluginsDir then
      [ ]
    else
      let
        luaFiles = lib.filter (path: lib.hasSuffix ".lua" (toString path)) (
          lib.filesystem.listFilesRecursive pluginsDir
        );
        tokenRe = ''"([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"'';
        extractFromFile =
          path:
          let
            matches = builtins.filter builtins.isList (builtins.split tokenRe (builtins.readFile path));
            names = lib.unique (map builtins.head matches);
          in
          map (
            name:
            let
              parts = lib.splitString "/" name;
            in
            {
              inherit name;
              owner = builtins.elemAt parts 0;
              repo = builtins.elemAt parts 1;
              source_file = baseNameOf (toString path);
              user_plugin = true;
            }
          ) names;
      in
      lib.sort (a: b: a.name < b.name) (lib.concatMap extractFromFile luaFiles);

  # File-based LazyVim configuration stores specs in configFiles/plugins.
  # Discovering them here keeps every spec in the Nix-generated dev path
  # instead of allowing lazy.nvim to fetch it at runtime.
  userPlugins =
    if !cfg.enable then
      [ ]
    else if cfg.configFiles != null then
      scanPluginDirectory (cfg.configFiles + "/plugins")
    else
      fileLib.scanUserPlugins "${config.home.homeDirectory}/.config/${cfg.appName}";

  corePlugins = builtins.filter (p: p.is_core or false) (dataLib.pluginData.plugins or [ ]);

  extrasPlugins =
    let
      enabledExtrasFiles = map (extra: "extras.${extra.category}.${extra.name}") enabledExtras;
      isExtraEnabled = plugin: builtins.elem (plugin.source_file or "") enabledExtrasFiles;
      allExtrasPlugins = builtins.filter (p: !(p.is_core or false)) (dataLib.pluginData.plugins or [ ]);
    in
    builtins.filter isExtraEnabled allExtrasPlugins;

  allPluginSpecs = corePlugins ++ extrasPlugins ++ userPlugins ++ extraManagedPluginSpecs;

  # Plugins that lazy.nvim would fetch at runtime because lazyvim-nix's data
  # does not model them:
  #  - saghen/blink.cmp is declared by LazyVim's coding.blink extra, which
  #    LazyVim imports implicitly (cmp auto-detection), so it never appears in
  #    the enabled extras list that selects plugins from the data
  #  - rafamadriz/friendly-snippets (a blink.cmp dependency) is absent from the
  #    generated plugin data
  # Without an entry here both are cloned into $XDG_DATA_HOME on first start.
  # Keep this list small; prefer fixing the plugin data upstream.
  extraManagedPluginSpecs = [
    {
      name = "saghen/blink.cmp";
      pkg = pkgs.vimPlugins.blink-cmp;
    }
    {
      name = "rafamadriz/friendly-snippets";
      pkg = pkgs.vimPlugins.friendly-snippets;
    }
  ];

  # The whole Treesitter stack (parser binaries, queries, and the Lua API) must
  # come from a single nixpkgs evaluation. Mixing sources silently desynchronises
  # them: a parser can omit a node type that a query still references, and every
  # buffer of that language then fails with
  #   Query error at <line>: Invalid node type "<x>"
  # which surfaces as a BufReadPost error rather than a build failure.
  #
  # lazyvim-nix's `pluginSource = "latest"` builds parsers from
  # data/parser-manifest.json but takes queries from the nvim-treesitter plugin
  # pin in data/plugins.json. Those two pins drift independently (observed:
  # queries at 5cb0114, parsers at 539abf6, 22 of 61 languages skewed and 2
  # hard-failing on `diff` and `kotlin`). Prefer coherence over version chase
  # for the Treesitter stack specifically.
  resolvedTreesitterPlugin = pkgs.vimPlugins.nvim-treesitter;

  # Swap any LazyVim-resolved nvim-treesitter for the nixpkgs build so the Lua
  # API matches the parsers and queries linked into $XDG_DATA_HOME. Extra
  # managed plugins carry their package directly because they have no entry in
  # lazyvim-nix's data for the resolver to work from.
  resolvedPlugins =
    let
      base = map (pluginLib.resolvePlugin cfg) allPluginSpecs;
    in
    lib.zipListsWith (
      spec: plugin:
      if spec.name == "nvim-treesitter/nvim-treesitter" then
        resolvedTreesitterPlugin
      else if spec ? pkg then
        spec.pkg
      else
        plugin
    ) allPluginSpecs base;

  # lazy.nvim resolves a dev plugin as `${dev.path}/${plugin.name}`, where the
  # name is the repo name unless the spec sets `name`. LazyVim does that for a
  # few plugins, but lazyvim-nix's data does not record the override, so the
  # link is created under the repo name, lazy finds no link under its resolved
  # name, and clones the plugin into ~/.local/share/nvim/lazy on first start.
  # catppuccin/nvim is the visible case: lazy looks for `catppuccin`, while the
  # repo-name link would be `nvim`.
  #
  # Add an entry here when a plugin is still cloned at runtime.
  devPathAliases = {
    "catppuccin/nvim" = "catppuccin";
  };

  devPathLinkName =
    spec:
    let
      repoName = builtins.elemAt (lib.splitString "/" spec.name) 1;
      mapping = dataLib.pluginMappings.${spec.name} or null;
      isMultiModule = builtins.isAttrs mapping && mapping ? module;
    in
    if devPathAliases ? ${spec.name} then
      devPathAliases.${spec.name}
    else if isMultiModule then
      mapping.module
    else
      repoName;

  devPath =
    let
      entries = lib.zipListsWith (
        spec: plugin:
        if plugin == null then
          null
        else
          {
            name = devPathLinkName spec;
            inherit plugin;
          }
      ) allPluginSpecs resolvedPlugins;
      # First writer wins so a later duplicate spec cannot repoint a name.
      byName = lib.foldl' (
        acc: entry: if entry == null || acc ? ${entry.name} then acc else acc // { ${entry.name} = entry; }
      ) { } entries;
    in
    pkgs.runCommand "lazyvim-dev-path" { } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: entry: "ln -sf ${entry.plugin} $out/${name}") byName
      )}
    '';

  # lazy.nvim merges spec fragments by plugin name and, for `owner/repo`
  # strings, also by URL. lazyvim-nix emits `{ "<repo-name>", dev = true }`:
  # a bare name only merges when it equals lazy's resolved name, so a plugin
  # with a `name = ...` override is missed and a phantom plugin is registered
  # instead (catppuccin/nvim -> "nvim"). Emitting `owner/repo` merges through
  # the URL index regardless of renames.
  availableDevSpecs = lib.filter (s: s != null) (
    lib.zipListsWith (
      spec: plugin:
      if plugin != null && spec.name != "nvim-treesitter/nvim-treesitter" then
        ''{ "${spec.name}", dev = true, pin = true },''
      else
        null
    ) allPluginSpecs resolvedPlugins
  );
  extrasImportSpecs = configLib.extrasImportSpecs enabledExtras;
  treesitterGrammars = treesitterLib.treesitterGrammars automaticTreesitterParsers;

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

  # Parser/query drift otherwise only surfaces at runtime, per language, as
  #   Query error at <line>: Invalid node type "<x>"
  # the first time a file of that language is opened. Parse every installed
  # query against its parser with the runtime Neovim at build time instead, so
  # drift fails the home-manager build and names the offending language/query.
  treesitterQueryCheck = pkgs.writeText "treesitter-query-check.lua" ''
    local site = assert(arg[1], "usage: nvim -l treesitter-query-check.lua <site>")
    vim.opt.runtimepath:prepend(site)

    local checked, failures = 0, {}
    for file in vim.fs.dir(site .. "/parser") do
      local lang = file:match("^(.+)%.so$")
      if lang then
        local query_dir = site .. "/queries/" .. lang
        local ok, added, err = pcall(vim.treesitter.language.add, lang)
        if not (ok and added) then
          failures[#failures + 1] = ("%s: parser failed to load: %s"):format(lang, tostring(ok and err or added))
        elseif vim.uv.fs_stat(query_dir) then
          for query_file in vim.fs.dir(query_dir) do
            local query = query_file:match("^(.+)%.scm$")
            if query then
              checked = checked + 1
              local qok, qerr = pcall(vim.treesitter.query.get, lang, query)
              if not qok then
                failures[#failures + 1] = ("%s/%s: %s"):format(lang, query, (tostring(qerr):gsub("%s+", " ")))
              end
            end
          end
        end
      end
    end

    if #failures > 0 then
      io.stderr:write("Treesitter parser/query mismatch:\n  " .. table.concat(failures, "\n  ") .. "\n")
      io.stderr:write("Parsers, queries, and nvim-treesitter must come from one nixpkgs evaluation.\n")
      os.exit(1)
    end
    print(("treesitter: %d queries parse against their parsers"):format(checked))
  '';

  validatedQueries =
    pkgs.runCommand "treesitter-queries-validated"
      { nativeBuildInputs = [ config.programs.neovim.package ]; }
      ''
        export HOME="$TMPDIR"
        mkdir -p "$TMPDIR/site"
        ln -s ${treesitterGrammars}/parser "$TMPDIR/site/parser"
        ln -s ${filteredQueries} "$TMPDIR/site/queries"
        nvim --clean -l ${treesitterQueryCheck} "$TMPDIR/site"
        ln -s ${filteredQueries} $out
      '';

  lazyConfigRaw = configLib.lazyConfig {
    starterLua = dataLib.starterLua;
    starterVersion = dataLib.starterVersion;
    inherit devPath extrasImportSpecs availableDevSpecs;
  };

  # The LazyVim starter bootstraps lazy.nvim by git-cloning it into
  # `stdpath("data")/lazy/lazy.nvim`. Under Nix that is unnecessary and
  # non-hermetic: home-manager already links the Nix package into
  # `stdpath("data")/site/pack/hm/start`, and Nvim resolves `require("lazy")`
  # from start packages before any plugin loads. Drop the bootstrap block; a
  # missing package then fails loudly at `require("lazy")` instead of cloning
  # an unpinned copy into $XDG_DATA_HOME.
  lazyBootstrapOriginal = ''
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
      if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
          { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
          { out, "WarningMsg" },
          { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
      end
    end
    vim.opt.rtp:prepend(lazypath)
  '';

  lazyBootstrapReplacement = ''
    -- [NIX] lazy.nvim is provided by Nix via `site/pack/hm/start`; no bootstrap.
  '';

  lazyConfig =
    let
      patched =
        builtins.replaceStrings [ lazyBootstrapOriginal ] [ lazyBootstrapReplacement ]
          lazyConfigRaw;
    in
    if patched == lazyConfigRaw then
      throw ''
        lazyvim-nix: could not patch the lazy.nvim bootstrap block in the
        generated config. The upstream LazyVim starter text changed; update
        lazyBootstrapOriginal in modules/_internal/neovim/lazyvim-nix-module.nix.
      ''
    else
      patched;

  extrasConfigFiles = configLib.extrasConfigFiles enabledExtras cfg.appName;
  scannedFiles = fileLib.scanConfigFiles cfg.configFiles cfg.appName;
  conflictChecks = fileLib.detectConflicts cfg scannedFiles;
  _ = if cfg.enable then conflictChecks else null;
in
{
  options.programs.lazyvim = import (lazyvimNixPath + "/options.nix") { inherit lib dataLib; };

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
        source = "${validatedQueries}";
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
    );
  };
}
