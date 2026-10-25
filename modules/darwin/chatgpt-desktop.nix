{ ... }:
{
  aw1cks.modules.darwin.chatgpt-desktop =
    { config, lib, ... }:
    {
      options.aw1cks.chatgptDesktop.enable = lib.mkEnableOption "the official ChatGPT desktop app via Homebrew";

      config = lib.mkIf config.aw1cks.chatgptDesktop.enable {
        homebrew.enable = true;
        homebrew.casks = [ "chatgpt" ];
      };
    };
}
