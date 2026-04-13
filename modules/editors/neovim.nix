{ ... }:
{
  aw1cks.modules.home.neovim =
    { config, pkgs, ... }:
    {
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        extraPackages = with pkgs; [ tree-sitter ];
        viAlias = true;
        vimAlias = true;
      };

      home.sessionVariables = {
        # We use an absolute path for SUDO_EDITOR.
        # home-manager hosts will not have the nix PATH setup and silently fall back.
        # NOTE: this can go stale when a new HM generation is built.
        # TODO: add a guard condition to avoid this for darwin/nixos
        SUDO_EDITOR = "${config.programs.neovim.finalPackage}/bin/nvim";
        VISUAL = "nvim";
      };
    };
}
