# Home-manager self-management — migrated from nix-old/modules/home-manager.nix
{ dl, ... }:
{
  dl.base-home-manager.homeManager = {
    programs.home-manager.enable = true;
    services.home-manager.autoExpire = {
      enable = true;
      frequency = "weekly";
      store = {
        cleanup = true;
        options = "--delete-older-than 7d";
      };
    };
    news.display = "silent";
  };
}
