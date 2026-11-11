{
  inputs,
  lib,
  pkgs,
  kataModule,
  fixtureModules ? [ ],
}:
let
  mkFixture =
    extraModules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        kataModule
        {
          home.username = "kata-check";
          home.homeDirectory = "/build/kata-check";
          home.stateVersion = "25.05";
          services.kata.enable = true;
        }
      ]
      ++ extraModules;
    };
  # No Tern import: Kata must remain a standalone Home Manager service.
  fixture = mkFixture fixtureModules;
  evaluated = builtins.unsafeDiscardStringContext fixture.activationPackage.drvPath;
  rejected =
    module:
    !(builtins.tryEval
      (fixture.extendModules { modules = [ module ]; }).config.home.activationPackage.drvPath
    ).success;
  invalidStateDirectories = [
    "relative/kata"
    "/nix/store"
    "/nix/store/"
    "/nix/store/kata"
    "/build/../kata"
    "/build/kata/.."
  ];
  invalidListenAddresses = [
    "0.0.0.0"
    "::"
    "192.0.2.1"
    "localhost"
    "*"
  ];
  invalidPorts = [
    0
    (-1)
    65536
    "7777"
  ];
  disabledFixture = mkFixture [
    {
      services.kata = {
        enable = lib.mkForce false;
        package = throw "Disabled Kata must not require a package";
        stateDirectory = throw "Disabled Kata must not require state";
      };
    }
  ];
  boundaryFixture = mkFixture [
    {
      services.kata = {
        stateDirectory = "/var/tmp/kata-check";
        listenAddress = "::1";
        port = 1;
        autostart = false;
      };
    }
  ];
  highPortFixture = mkFixture [ { services.kata.port = 65535; } ];
in
assert lib.all rejected (
  map (stateDirectory: { services.kata = { inherit stateDirectory; }; }) invalidStateDirectories
  ++ map (listenAddress: { services.kata = { inherit listenAddress; }; }) invalidListenAddresses
  ++ map (port: { services.kata = { inherit port; }; }) invalidPorts
);
assert builtins.isString disabledFixture.activationPackage.drvPath;
assert builtins.isString boundaryFixture.activationPackage.drvPath;
assert builtins.isString highPortFixture.activationPackage.drvPath;
pkgs.runCommand "kata-service-checks"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    passthru = { inherit fixture mkFixture; };
    evaluatedHome = evaluated;
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    python3 -m unittest discover -s ${./.} -p 'test_prepare_state.py' -v
    printf '%s\n' "$evaluatedHome" > "$out"
  ''
