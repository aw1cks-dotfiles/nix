{ inputs, lib, pkgs, ternModule, fixtureModules ? [] }:
let
  mkFixture = extraModules: inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [ ternModule {
      home.username = "tern-check";
      home.homeDirectory = "/build/tern-check";
      home.stateVersion = "25.05";
      modules.tern = { enable = true; package = null; executable = "/opt/tern/bin/tern"; };
      services.tern = { daemon.enable = true; remote.enable = true; };
    } ] ++ extraModules;
  };
  fixture = mkFixture fixtureModules;
  evaluated = builtins.unsafeDiscardStringContext fixture.activationPackage.drvPath;
  migrationGuard = pkgs.writeShellScript "tern-migration-guard" fixture.config.home.activation.checkTernSupervisors.data;
  rejected = module: !(builtins.tryEval
    (fixture.extendModules { modules = [ module ]; }).config.home.activationPackage.drvPath).success;
  unsafeNames = [ "" "." ".." "../escape" "/absolute" "nested/name" "with space" "line\nbreak" ];
  invalidAssets = map (name: { modules.tern.themes.${name}.source = ./checks.nix; }) unsafeNames;
  reservedNames = map (name: { modules.tern.themes.${name}.source = ./checks.nix; }) [ "nix-managed-dark" "nix-managed-light" ];
  invalidPalettes = lib.concatMap
    (field: map (count: { modules.tern.theme.palette.${field} = lib.replicate count "#123456"; }) [ 0 7 9 ])
    [ "ansi" "brights" ];
in
assert rejected { services.tern.remote.relay.enable = true; };
assert rejected { modules.tern.socket = "/${lib.concatStrings (lib.replicate 108 "x")}"; };
assert lib.all rejected (invalidAssets ++ reservedNames ++ invalidPalettes);
pkgs.runCommand "tern-settings-checks" {
  nativeBuildInputs = [ pkgs.python3 ];
  passthru = { inherit fixture mkFixture; };
  evaluatedHome = evaluated;
} ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 -m unittest discover -s ${./.} -p 'test_*.py' -v
  ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
    if XDG_RUNTIME_DIR="$TMPDIR/no-user-manager" ${pkgs.bash}/bin/bash ${migrationGuard}; then
      echo "Tern supervisor inspection must fail closed without a user manager" >&2
      exit 1
    fi
  ''}
  printf '%s\n' "$evaluatedHome" > "$out"
''
