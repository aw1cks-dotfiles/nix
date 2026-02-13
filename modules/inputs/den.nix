{ lib, ... }:
{
  flake-file.inputs.den = {
    url = lib.mkForce "github:vic/den/v0.8.0";
  };
}
