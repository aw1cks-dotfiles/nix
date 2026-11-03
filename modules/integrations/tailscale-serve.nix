{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.tailscale-serve-reconcile = import ./_tailscale-serve-package.nix { inherit pkgs; };
      checks.tailscale-serve =
        pkgs.runCommand "tailscale-serve-authoritative-apply"
          {
            nativeBuildInputs = [ pkgs.python3 ];
          }
          ''
            export PYTHONDONTWRITEBYTECODE=1
            python3 -m unittest discover -s ${../home/networking/files/tailscale-serve} -p 'test*.py' -v
            touch "$out"
          '';
    };
}
