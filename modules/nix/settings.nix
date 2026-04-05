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
        "https://wezterm.cachix.org"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "wezterm.cachix.org-1:kAbhjYUC9qvblTE+s7S+kl5XM1zVa4skO+E/1IDWdH0="
      ];

      keep-outputs = true;
    };

    flake.modules = {
      nixos.nix-settings.nix.settings = config.nix.settings;
      darwin.nix-settings.nix.settings = config.nix.settings;
      home.nix-settings =
        {
          lib,
          pkgs,
          osConfig ? null,
          ...
        }:
        {
          nix.package = lib.mkDefault (if osConfig != null then osConfig.nix.package else pkgs.nix);
          nix.settings = config.nix.settings;
        };
    };
  };
}
