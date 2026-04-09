{
  inputs,
  config,
  ...
}:
{
  perSystem =
    {
      system,
      pkgs,
      ...
    }:
    let
      updateScript = pkgs.replaceVars ./files/update-nvidia-version.py {
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
        meta.description = "Run the Home Manager CLI from this flake's pinned input";
      };

      packages.update-nvidia-version = nvidiaUpdateScript;
    };
}
