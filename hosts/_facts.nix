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
    user = "alex";
    homeDirectory = "/Users/alex";
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
    user = "alex";
    homeDirectory = "/home/alex";
    tags = [ "nvidia" ];
  };
}
