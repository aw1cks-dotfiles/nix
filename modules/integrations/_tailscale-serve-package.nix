{ pkgs }:
pkgs.writeShellApplication {
  name = "tailscale-serve-reconcile";
  text = ''
    exec ${pkgs.python3}/bin/python3 ${../home/networking/files/tailscale-serve/apply.py} "$@"
  '';
}
