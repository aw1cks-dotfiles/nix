{ lib, inputs, ... }:
{
  perSystem =
    {
      system,
      pkgs,
      ...
    }:
    let
      patchedNixVmTest = {
        lib.${system} =
          import
            (
              pkgs.applyPatches {
                name = "nix-vm-test-vm-start-scripts";
                src = inputs.nix-vm-test;
                patches = [ ./patches/nix-vm-test-vm-start-scripts.patch ];
              }
              + "/lib.nix"
            )
            {
              nixpkgs = inputs.nixpkgs-unstable.outPath;
              inherit system;
            };
      };

      installHostKexecTest = import (inputs.nixos-anywhere + "/tests/linux-kexec-test.nix") {
        inherit pkgs;
        nixos-anywhere = inputs.nixos-anywhere.packages.${system}.default;
        nix-vm-test = patchedNixVmTest;
        system-to-install = inputs.self.nixosConfigurations.desktop;
        kexec-installer = "${
          inputs.nixos-images.packages.${system}.kexec-installer-nixos-unstable-noninteractive
        }/nixos-kexec-installer-noninteractive-${system}.tar.gz";
        distribution = "ubuntu";
        version = "24_04";
      };
    in
    lib.mkIf
      (
        pkgs.stdenv.hostPlatform.isLinux
        && system == "x86_64-linux"
        && inputs ? nix-vm-test
        && inputs ? nixos-images
        && inputs ? nixos-anywhere
      )
      {
        packages.install-host-kexec-test = installHostKexecTest;

        apps.install-host-kexec-test = {
          type = "app";
          program = "${pkgs.writeShellScript "install-host-kexec-test" ''
            exec nix build --print-out-paths --no-link .#install-host-kexec-test
          ''}";
          meta.description = "Run a disposable SSH-target kexec rehearsal for desktop provisioning";
        };
      };
}
