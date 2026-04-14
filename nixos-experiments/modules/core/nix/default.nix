{ pkgs, ...}:
{
  nix = {
    settings = {
      download-buffer-size = 524288000; # 500 MB (250 * 1024 * 1024)
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        # high priority since it's almost always used
        "https://cache.nixos.org?priority=10"

        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
      ];
    };

    gc = {
      automatic = true;
      persistent = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
