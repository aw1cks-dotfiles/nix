# Nix daemon settings — projected to all configuration classes
{ lib, config, ... }:
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

    flake.modules = {
      nixos.nix-settings.nix.settings = config.nix.settings;
      darwin.nix-settings.nix.settings = config.nix.settings;
      home.nix-settings =
        { pkgs, ... }:
        {
          nix.package = pkgs.nix;
          nix.settings = config.nix.settings;
        };
    };
  };
}
