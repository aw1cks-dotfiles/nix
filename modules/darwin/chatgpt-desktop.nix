{ ... }:
{
  aw1cks.modules.darwin.chatgpt-desktop =
    { config, lib, ... }:
    {
      options.modules.ai.chatgpt.enable =
        lib.mkEnableOption "the official ChatGPT desktop app via Homebrew";

      config = lib.mkIf config.modules.ai.chatgpt.enable {
        homebrew.enable = true;
        homebrew.casks = [ "chatgpt" ];
      };
    };
}
