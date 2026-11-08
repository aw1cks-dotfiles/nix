{
  config,
  inputs,
  lib,
  ...
}:
{
  aw1cks.modules.home.language-servers =
    { pkgs, ... }:
    {
      home.packages = import ./_language-servers.nix { inherit pkgs; };

      # User config has higher precedence than project .clangd files: keep
      # shared diagnostics here, but leave language standards to each project.
      home.file = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        "Library/Preferences/clangd/config.yaml".source = ./files/clangd/config.yaml;
      };
      xdg.configFile = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        "clangd/config.yaml".source = ./files/clangd/config.yaml;
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      checks.clangd-policy = import ./_clangd-policy-check.nix {
        inherit inputs lib pkgs;
        languageServersModule = config.aw1cks.modules.home.language-servers;
      };
    };
}
