{ config, ... }:
let
  inherit (config.flake) modules;
in
{
  flake.profiles.home.developer = {
    # General development toolchain used across workstation-style hosts.
    imports = [
      modules.home.dev-tools
      modules.home.ai
      modules.home.containers
      modules.home.rust
      modules.home.kubernetes
      modules.home.java
    ];
  };
}
