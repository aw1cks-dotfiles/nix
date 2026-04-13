{ lib, config, ... }:
let
  inherit (config.aw1cks) profiles;
in
{
  options.aw1cks.roles = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Central role-to-profile mappings used by constructors.";
  };

  config = {
    aw1cks.roles = {
      home = {
        base = [ profiles.home.base ];
        roles = {
          developer = [ profiles.home.developer ];
          desktop = [ profiles.home.desktop ];
          interactive = [ profiles.home.interactive ];
          multimedia = [ profiles.home.multimedia ];
        };
      };

      darwin = {
        base = [ ];
        roles = {
          desktop = [ profiles.darwin.desktop ];
        };
      };

      nixos = {
        base = [ ];
        roles = {
          desktop = [ profiles.nixos.desktop ];
          server = [ profiles.nixos.server ];
        };
      };
    };
  };
}
