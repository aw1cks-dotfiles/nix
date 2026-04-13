{ ... }:
{
  aw1cks.hostFacts = {
    # Standalone Home Manager example:
    # "your-user@laptop" = {
    #   system = "x86_64-linux";
    #   kind = "home-manager";
    #   roles = [
    #     "desktop"
    #     "developer"
    #     "interactive"
    #   ];
    #   identity = "work";
    #   tags = [ "nvidia" ];
    # };

    # NixOS example:
    # workstation = {
    #   system = "x86_64-linux";
    #   kind = "nixos";
    #   roles = [
    #     "desktop"
    #     "developer"
    #     "interactive"
    #   ];
    #   identity = "work";
    #   hostName = "workstation";
    # };
  };
}
