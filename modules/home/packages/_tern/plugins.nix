{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.tern;
  safeId = id: builtins.match "[a-z0-9-]{1,32}" id != null && id != "tern";
  enabledPlugins = lib.filterAttrs (_: plugin: plugin.enable) cfg.plugins;
  validatedSource =
    id: plugin:
    let
      source = "${plugin.source}";
    in
    assert lib.assertMsg (safeId id)
      "modules.tern.plugins key ${builtins.toJSON id} must be 1–32 lowercase letters, digits or hyphens; tern is reserved.";
    assert lib.assertMsg (lib.hasPrefix "${builtins.storeDir}/" source)
      "modules.tern.plugins.${id}.source must be an immutable Nix store path.";
    pkgs.runCommand "tern-plugin-${id}"
      {
        nativeBuildInputs = [ pkgs.python3 ];
        pluginSource = source;
        pluginId = id;
      }
      ''
        python3 ${./validate-plugin.py} --id "$pluginId" --source "$pluginSource"
        ln -s -- "$pluginSource" "$out"
      '';
in
{
  options.modules.tern.plugins = lib.mkOption {
    default = { };
    description = "Mergeable registry of opt-in native Tern plugins. Keys are manifest IDs: 1–32 lowercase letters, digits or hyphens, excluding reserved ID tern. Sources remain immutable; mutable plugin data stays in Tern's writable configuration directory.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "this native Tern plugin";
          source = lib.mkOption {
            type = lib.types.path;
            description = "Plugin source directory in the Nix store, including plugin.toml. Local Nix path values are copied to the store. Required and validated only when enabled.";
          };
          runtimePackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
            description = "Tools installed in the home profile and prepended to managed Tern launcher and service PATHs when this plugin is enabled.";
          };
        };
      }
    );
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all safeId (builtins.attrNames cfg.plugins);
        message = "modules.tern.plugins keys must be native plugin IDs: 1–32 lowercase letters, digits or hyphens; tern is reserved.";
      }
    ];
    home.packages = lib.concatMap (plugin: plugin.runtimePackages) (builtins.attrValues enabledPlugins);
    # Check before Home Manager changes links: a directory or alias can load the
    # same manifest ID first even though it does not own our exact .path filename.
    home.activation.checkTernPluginCollisions = lib.mkIf (enabledPlugins != { }) (
      lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        ${pkgs.python3}/bin/python3 ${./check-plugin-collisions.py} \
          --root ${lib.escapeShellArg "${cfg.configDirectory}/plugins"} \
          ${lib.escapeShellArgs (map (id: "--id=${id}") (builtins.attrNames enabledPlugins))}
      ''
    );
    # Own individual pointers only: never replace the writable plugins directory
    # or remove the data that Tern and unmanaged plugins maintain beside them.
    home.file = lib.mapAttrs' (
      id: plugin:
      lib.nameValuePair
        "${lib.removePrefix "${config.home.homeDirectory}/" cfg.configDirectory}/plugins/${id}.path"
        {
          text = "${validatedSource id plugin}\n";
        }
    ) enabledPlugins;
  };
}
