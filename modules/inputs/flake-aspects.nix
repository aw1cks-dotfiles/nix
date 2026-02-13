{ lib, ... }:
{
  flake-file.inputs.flake-aspects = {
    url = lib.mkDefault "github:vic/flake-aspects";
  };
}
