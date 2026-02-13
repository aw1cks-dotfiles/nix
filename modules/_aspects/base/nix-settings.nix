# Nix daemon settings for home-manager
{ dl, lib, config, ... }:
{
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
      keep-outputs = true;
    };

    dl.base-nix-settings.homeManager =
      { pkgs, ... }:
      {
        nix.package = pkgs.nix;
        nix.settings = config.nix.settings;
      };
  };
}
