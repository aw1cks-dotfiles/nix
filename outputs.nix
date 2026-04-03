inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [
    (inputs.import-tree ./modules)
    (inputs.import-tree ./hosts)
  ];
}
