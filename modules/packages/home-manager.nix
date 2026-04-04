# Home-manager self-management — migrated from nix-old/modules/home-manager.nix
{ ... }:
{
  flake.modules.home.home-manager = {
    programs = {
      home-manager.enable = true;
      nh.enable = true;
      nix-index.enable = true;
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
