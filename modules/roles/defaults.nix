{ lib, config, ... }:
let
  inherit (config.flake) profiles;
in
{
  options.flake.roles = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Central role-to-profile mappings used by constructors.";
  };

  config.flake.roles = {
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
      roles = { };
    };
  };
}
