{ pkgs, ... }:
{
  programs.zsh.enable = true;
  # This is just to stop the incessant nagging when no config file exists, we'll create a proper zshrc later
  system.userActivationScripts.zshrc = "touch .zshrc";
}
