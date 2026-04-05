{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.interactive = {
    # Interactive shell and identity tooling for human-operated machines.
    imports = [
      modules.home.cli-tools
      modules.home.git
      modules.home.git-config
      modules.home.gpg
      modules.home.zsh
    ];
  };
}
