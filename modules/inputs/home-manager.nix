{
  inputs,
  lib,
  config,
  ...
}:
{
  flake-file.inputs.home-manager = {
    url = lib.mkDefault "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = lib.mkDefault "nixpkgs";
  };

  # Expose home-manager CLI as the default app
  perSystem =
    {
      system,
      pkgs,
      ...
    }:
    let
      updateScript = pkgs.replaceVars ./update-nvidia-version.py {
        nvidiaHostsJson = builtins.toJSON config.flake.homeNvidiaConfigurations;
      };
      nvidiaUpdateScript = pkgs.writeShellApplication {
        name = "update-nvidia-version";
        runtimeInputs = [
          pkgs.git
          pkgs.nix
          pkgs.python3
        ];
        text = ''
          exec -a update-nvidia-version ${pkgs.python3}/bin/python3 ${updateScript} "$@"
        '';
      };
    in
    {
      apps.home-manager = {
        type = "app";
        program = "${inputs.home-manager.packages.${system}.home-manager}/bin/home-manager";
      };

      packages.update-nvidia-version = nvidiaUpdateScript;
    };
}
