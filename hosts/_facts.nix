{
  mbp = {
    system = "aarch64-darwin";
    kind = "darwin";
    roles = [
      "desktop"
      "developer"
      "interactive"
      "multimedia"
    ];
    identity = "personal";
    hostName = "mbp";
  };

  "alex@desktop" = {
    system = "x86_64-linux";
    kind = "home-manager";
    roles = [
      "desktop"
      "developer"
      "interactive"
      "multimedia"
    ];
    identity = "personal";
    tags = [ "nvidia" ];
  };
}
