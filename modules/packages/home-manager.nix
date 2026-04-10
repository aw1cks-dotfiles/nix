# Home-manager self-management — migrated from nix-old/modules/home-manager.nix
{ config, ... }:
{
  flake.modules.home.home-manager = {
    imports = [
      config.flake.modules.home.nix-index-database
      config.flake.modules.home.command-not-found
    ];

    programs = {
      home-manager.enable = true;
      nh.enable = true;
      nix-index = {
        enable = true;
        # We disable these in favour of our own command-not-found implementation.
        # This was done to customise the output format.
        # See config.flake.modules.home.command-not-found
        enableBashIntegration = false;
        enableZshIntegration = false;
      };
      nix-init.enable = true;
    };
    services.home-manager.autoExpire = {
      enable = true;
      frequency = "weekly";
      store = {
        cleanup = true;
        options = "--delete-older-than 7d";
      };
    };
    news.display = "silent";
    manual = {
      html.enable = true;
      manpages.enable = true;
    };
  };
}
