{ lib, config, ... }:
let
  identityType = lib.types.submodule (
    { ... }:
    {
      options = {
        fullName = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Human display name for this identity.";
        };

        email = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "Primary email address for this identity.";
        };

        username = lib.mkOption {
          type = lib.types.singleLineStr;
          description = "POSIX username for this identity.";
        };

        homeDirectory = lib.mkOption {
          type = lib.types.nullOr lib.types.singleLineStr;
          default = null;
          description = "Optional home directory override for this identity.";
        };
      };
    }
  );
in
{
  options.aw1cks = {
    identities = lib.mkOption {
      type = lib.types.lazyAttrsOf identityType;
      default = { };
      description = "Named registry of reusable public identities.";
    };

    identity.default = lib.mkOption {
      type = lib.types.str;
      default = "personal";
      description = "Name of the default selected identity in aw1cks.identities.";
    };

    identity.selected = lib.mkOption {
      type = identityType;
      readOnly = true;
      description = "Resolved default identity entry selected from aw1cks.identities.";
    };
  };

  config.aw1cks = {
    identities.personal = {
      fullName = lib.mkDefault "Alex Wicks";
      email = lib.mkDefault "alex@awicks.io";
      username = lib.mkDefault "alex";
    };

    identity.selected =
      if builtins.hasAttr config.aw1cks.identity.default config.aw1cks.identities then
        config.aw1cks.identities.${config.aw1cks.identity.default}
      else
        throw "aw1cks.identity.default must reference an entry in aw1cks.identities.";
  };
}
