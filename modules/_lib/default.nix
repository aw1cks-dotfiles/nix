{
  # Generate a module for both NixOS and darwin from a single config
  mkSystemModule = mod: {
    nixos = mod;
    darwin = mod;
  };

  # Generate modules for all three classes from a single config
  mkPolyModule = mod: {
    nixos = mod;
    darwin = mod;
    home = mod;
  };
}
