{ ... }:
{
  configurations.darwin.mbp = {
    module = {
      system.stateVersion = 6;
    };
    home = {
      modules.lazyvim.enable = true;
      modules.ai.opencode.ollama = {
        enable = true;
        endpoint = "desktop.gentoo-boa.ts.net";
        models = {
          "gemma4:26b" = {
            name = "Gemma 4 26B";
          };
        };
      };
      home = {
        stateVersion = "25.11";
      };
    };
  };
}
