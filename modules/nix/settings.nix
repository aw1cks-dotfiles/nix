# Nix daemon settings — projected to all configuration classes
{ lib, config, ... }:
let
  sharedSettings = config.nix.settings;

  mkSettingsAdapter =
    extra:
    {
      nix.settings = sharedSettings;
    }
    // extra;
in
{
  options.nix.trustedUsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Additional trusted users to pass through to nix-darwin's nix.settings.trusted-users.";
  };

  options.nix.settings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  config = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Shared inputs can publish their own binary caches. Add the ones we know
      # about here so downstream home-manager / nixos / darwin consumers all get
      # the same substitute coverage instead of rebuilding tool packages locally.
      extra-substituters = [
        "https://cache.numtide.com"
        "https://wezterm.cachix.org"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="
      ];

      keep-outputs = true;
    }
    // lib.optionalAttrs (config.nix.trustedUsers != [ ]) {
      trusted-users = lib.unique config.nix.trustedUsers;
    };

    flake.modules = {
      nixos.nix-settings = mkSettingsAdapter { };
      darwin.nix-settings = mkSettingsAdapter { };
      home.nix-settings =
        {
          lib,
          pkgs,
          config,
          osConfig ? null,
          ...
        }:
        mkSettingsAdapter {
          nix.package = lib.mkDefault (
            if osConfig != null then
              osConfig.nix.package
            else if lib.attrByPath [ "repo" "lix" "enable" ] false config then
              pkgs.lix
            else
              pkgs.nix
          );
        };
    };
  };
}
