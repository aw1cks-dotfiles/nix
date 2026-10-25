# Opt-in real-daemon test: nix build .#cache-bootstrap-vm-test (Linux/KVM).
# This tests the transaction against a standalone-style config in a disposable
# NixOS VM. It does not prove full first HM activation or macOS service handling.
{ pkgs, source }:
let
  tls = pkgs.runCommand "cache-bootstrap-test-tls" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir -p "$out"
    openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
      -subj /CN=cache -addext subjectAltName=DNS:cache \
      -addext basicConstraints=critical,CA:TRUE \
      -keyout "$out/key.pem" -out "$out/cert.pem"
  '';
in
pkgs.testers.runNixOSTest {
  name = "cache-bootstrap-daemon";
  nodes = {
    cache = {
      nix.package = pkgs.lix;
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      services.nginx = {
        enable = true;
        virtualHosts.cache = {
          onlySSL = true;
          sslCertificate = "${tls}/cert.pem";
          sslCertificateKey = "${tls}/key.pem";
          root = "/srv/cache";
        };
      };
      networking.firewall.allowedTCPPorts = [ 443 ];
      environment.systemPackages = [ pkgs.bash ];
    };
    client = { lib, ... }: {
      nix.package = pkgs.lix;
      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        substituters = lib.mkForce [ ];
        trusted-public-keys = lib.mkForce [ ];
        trusted-users = lib.mkForce [ "root" ];
      };
      security.pki.certificateFiles = [ "${tls}/cert.pem" ];
      users.users.alice = { isNormalUser = true; };
      environment.systemPackages = [ pkgs.bash ];
      environment.etc."cache-bootstrap/daemon-lib.sh".source = "${source}/modules/integrations/_cache-bootstrap/daemon-lib.sh";
    };
  };
  testScript = ''
    import hashlib
    import shlex

    start_all()
    cache.wait_for_unit("nginx.service")
    client.wait_for_unit("nix-daemon.socket")
    cache.succeed("mkdir -p /srv/cache; chmod 755 /srv/cache")
    cache.succeed("nix-store --generate-binary-cache-key fixture /tmp/old.sec /tmp/old.pub")
    cache.succeed("nix-store --generate-binary-cache-key fixture /tmp/new.sec /tmp/new.pub")

    # Replace only inside this disposable VM. The public installer intentionally
    # refuses NixOS-owned config; call the transaction library to isolate testing
    # of persistence, restart, ordinary-user trust, and rotation.
    baseline = "build-users-group = nixbld\nrequire-sigs = true\nsubstituters =\ntrusted-public-keys =\nextra-experimental-features = nix-command flakes\n"
    client.succeed("rm /etc/nix/nix.conf; printf %s " + shlex.quote(baseline) + " > /etc/nix/nix.conf; chmod 644 /etc/nix/nix.conf; systemctl restart nix-daemon")

    def make_path(name, key):
        expr = 'derivation { name = "' + name + '"; system = builtins.currentSystem; builder = (builtins.storePath "${pkgs.bash}") + "/bin/bash"; args = [ "-c" "echo fixture > $out" ]; }'
        path = cache.succeed("nix-build --no-out-link --expr " + shlex.quote(expr)).strip()
        cache.succeed("nix store sign --key-file /tmp/" + key + ".sec " + path)
        cache.succeed("nix copy --to file:///srv/cache " + path)
        client.succeed("test ! -e " + path)
        return path

    def install(key):
        pub = cache.succeed("cat /tmp/" + key + ".pub").strip()
        policy = "# Managed by aw1cks cache bootstrap v1\n# Inventory sha256: " + hashlib.sha256(pub.encode()).hexdigest() + "\nextra-substituters = https://cache\nextra-trusted-public-keys = " + pub + "\n"
        client.succeed("printf %s " + shlex.quote(policy) + " > /tmp/policy")
        script = "set -eu; . ${source}/modules/integrations/_cache-bootstrap/daemon-lib.sh; cache_nix=${pkgs.lix}/bin/nix; cache_service=systemd; cache_transaction /etc/nix < /tmp/policy"
        client.succeed("sh -c " + shlex.quote(script))

    def request(path):
        command = "NIX_REMOTE=daemon nix-store --realise " + path + " --option max-jobs 0 --option extra-local-jobs 0 --option builders \"\""
        return "su - alice -c " + shlex.quote(command)

    first = make_path("signed-first", "old")
    client.fail(request(first))
    install("old")
    client.succeed(request(first))
    install("old")
    client.succeed("test $(grep -c '^include /etc/nix/aw1cks-caches.conf$' /etc/nix/nix.conf) -eq 1")
    install("new")
    retired = make_path("retired-key-only", "old")
    client.fail(request(retired))
    fresh = make_path("new-key-only", "new")
    client.succeed(request(fresh))
    cache.succeed("grep -q narinfo /var/log/nginx/access.log")
  '';
}
