# Nix daemon settings — projected to all configuration classes
{ lib, config, ... }:
let
  caches = import ./_cache-list.nix;

  sharedSettings = {
    nix-path = [ ];

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Shared inputs can publish their own binary caches. The authoritative list
    # lives in ./cache-list.nix so that the bootstrap-cache app can generate an
    # identical nix.conf from the same source without duplicating entries here.
    extra-substituters = caches.substituters;
    extra-trusted-public-keys = caches.trustedPublicKeys;

    keep-outputs = true;
  };

  mkSettingsAdapter =
    extra:
    lib.recursiveUpdate {
      nix.settings = sharedSettings;
    } extra;
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
    nix.settings =
      sharedSettings
      // lib.optionalAttrs (config.nix.trustedUsers != [ ]) {
        trusted-users = lib.unique config.nix.trustedUsers;
      };

    aw1cks.modules = {
      nixos.nix-settings = mkSettingsAdapter {
        nix = {
          channel.enable = false;
          settings.auto-optimise-store = lib.mkDefault true;
        };
      };
      darwin.nix-settings = mkSettingsAdapter {
        nix.settings.auto-optimise-store = lib.mkDefault true;
      };
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
