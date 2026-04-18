{ lib, ... }:
let
  entries = builtins.readDir ./.;
  hostImports = lib.pipe entries [
    (lib.mapAttrsToList (
      name: type:
      if type == "directory" && builtins.pathExists (./. + "/${name}/configuration.nix") then
        ./. + "/${name}/configuration.nix"
      else
        null
    ))
    (builtins.filter (path: path != null))
  ];
in
{
  _file = ./default.nix;

  imports = [ ./facts.nix ] ++ hostImports;
}
