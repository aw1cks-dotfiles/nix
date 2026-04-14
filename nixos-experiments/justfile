BUILD_MEM_MB := "16384"

export TESTVM_NUM_CORES := env("TESTVM_NUM_CORES", "8")
export TESTVM_MEM_MB    := env("TESTVM_MEM_MB", "16384")

export NIX_VM_BUILD := env("NIX_VM_BUILD", "1")

deploy machine:
    #!/bin/bash
    set -euo pipefail
    nix run nixpkgs#deploy-rs -- --flake '.#{{machine}}'

installSsh machine sshAddr:
  nix run github:nix-community/nixos-anywhere -- \
      --build-on auto \
      --flake '.#{{machine}}' \
      --target-host '{{sshAddr}}'

testvm machine:
    #!/bin/bash
    set -euo pipefail
    rm -vf '{{machine}}.raw'
    printf '{{YELLOW}}{{BOLD}}Building VM{{NORMAL}}\n'
    nix run --impure '.#make-image-{{machine}}'
    printf '{{CYAN}}{{BOLD}}Running VM{{NORMAL}}\n'
    nix run --impure '.#{{machine}}'

sshvm:
  ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no alex@localhost -p 2222

clean:
  rm -vf ./*.raw ./*.qcow2 ./*-efi-vars.fd ./result*
  nix gc
