{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.developer = {
    # Development toolchain for machines used for software work.
    imports = [
      modules.home.ai
      modules.home.containers
      modules.home.dev-tools
      modules.home.java
      modules.home.kubernetes
      modules.home.rust
    ];
  };
}
