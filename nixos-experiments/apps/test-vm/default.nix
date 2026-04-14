{ pkgs, hostPkgs ? pkgs, config, machineName, ... }:

let
  pkgsAarch64 = pkgs.pkgsCross.aarch64-multiplatform;
  pythonScript = builtins.readFile ./launch.py;
in
pkgs.writeShellApplication {
  name = "test-image";
  runtimeInputs = [ hostPkgs.python3 hostPkgs.qemu ];
  text = ''
    #!/bin/bash
    set -euo pipefail

    # Set defaults for VM resources, allowing overrides from environment
    : "''${TESTVM_NUM_CORES:=8}"
    : "''${TESTVM_MEM_MB:=16384}"
    export TESTVM_NUM_CORES
    export TESTVM_MEM_MB

    printf -- "--> Running VM for %s...\n" "${machineName}"
    export ARCH="${pkgs.stdenv.hostPlatform.system}"
    export MACHINE_TYPE="${config.my.system.type}"
    export NIXPKG_AARCH64_OVMF__FD="${pkgsAarch64.OVMF.fd}"
    export NIXPKG_X86_64_OVMF__FIRMWARE="${pkgs.OVMF.firmware}"
    export NIXPKG_X86_64_OVMF__VARIABLES="${pkgs.OVMF.variables}"

    python3 -c '${pythonScript}' "${machineName}.raw"
  '';
}
