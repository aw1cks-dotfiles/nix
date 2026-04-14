{ hostPkgs, machineName, ... }:

hostPkgs.writeShellApplication {
  name = "make-image";
  runtimeInputs = [ hostPkgs.nix hostPkgs.coreutils ];
  text = ''
    #!/bin/bash
    set -euo pipefail
    printf -- "--> Building VM image for %s (if changed)...\n" "${machineName}"
    IMAGE_STORE_PATH=$(nix build --impure --no-link --print-out-paths ".#packages.${hostPkgs.stdenv.hostPlatform.system}.${machineName}")
    printf -- "--> Creating writable image copy: %s.raw...\n" "${machineName}"
    cp --reflink=auto "$IMAGE_STORE_PATH" "${machineName}.raw"
    chmod 644 "${machineName}.raw"
    printf -- "--> Done: ${machineName}.raw\n"
  '';
}

