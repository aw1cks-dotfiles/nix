{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.interactive = {
    # Interactive shell and identity tooling for human-operated machines.
    imports = [
      modules.home.cli-tools
      modules.home.gpg
      modules.home.lazyvim
      modules.home.neovim
      modules.home.vcs
      modules.home.zsh
    ];
  };
}
