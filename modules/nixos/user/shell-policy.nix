{ lib, ... }:
{
  aw1cks.modules.nixos.user-shell-policy =
    {
      config,
      pkgs,
      resolvedUser,
      ...
    }:
    let
      shellPackage =
        {
          bash = pkgs.bashInteractive;
          zsh = pkgs.zsh;
        }
        .${config.aw1cks.user.shellPolicy};
    in
    {
      options.aw1cks.user.shellPolicy = lib.mkOption {
        type = lib.types.enum [
          "bash"
          "zsh"
        ];
        default = "bash";
        description = "Shell policy for the resolved primary NixOS user.";
      };

      config = {
        users.users.${resolvedUser}.shell = lib.mkOverride 900 shellPackage;
        programs.zsh.enable = lib.mkIf (config.aw1cks.user.shellPolicy == "zsh") (lib.mkDefault true);
      };
    };
}
