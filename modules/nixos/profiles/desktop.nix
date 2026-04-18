{ lib, ... }:
{
  aw1cks.profiles.nixos.desktop = {
    # Desktop hosts can opt into a richer shell baseline than servers.
    aw1cks.user.shellPolicy = lib.mkDefault "zsh";
  };
}
