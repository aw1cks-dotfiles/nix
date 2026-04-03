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

      # Shared inputs can publish their own binary caches. Add the ones we know
      # about here so downstream home-manager / nixos / darwin consumers all get
      # the same substitute coverage instead of rebuilding tool packages locally.
      extra-substituters = [
        "https://cache.numtide.com"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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
