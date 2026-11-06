{
  inputs,
  lib,
  pkgs,
  aiModule,
}:
let
  callerSkills = pkgs.writeTextDir "caller-only/SKILL.md" ''
    ---
    name: caller-only
    description: Skill provided by a caller-owned discovery directory.
    ---
    Preserve caller-owned skill directories.
  '';
  nativeSkills = pkgs.writeTextDir "native-only/SKILL.md" ''
    ---
    name: native-only
    description: Skill authored locally in the native OMP user directory.
    ---
    Preserve native user skills.
  '';
  replacement = ./_skills-fixtures/extra/cpp-coroutines;
  home =
    modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.hostFacts = { };
      modules = [
        inputs.oh-my-pi.homeManagerModules.default
        aiModule
        {
          home.username = "omp-skills-check";
          home.homeDirectory = "/build/omp-skills-check";
          home.stateVersion = "25.05";
          home.packages = lib.mkForce [ ];
          modules.ai.mcp.enable = false;
          modules.ai.omp.settings = {
            skills.customDirectories = [ (toString callerSkills) ];
            startup.quiet = true;
          };
          programs.omp.settings.theme.light = "caller-theme";
        }
      ]
      ++ modules;
    };
  cases = {
    default = home [ ];
    custom = home [
      {
        modules.ai.skills.select = lib.mkForce [ "builtin/git-workflow" ];
        modules.ai.skills.extra."external/cpp-coroutines" = replacement;
      }
    ];
    excluded = home [
      {
        modules.ai.skills.select = lib.mkForce [
          "builtin/*"
          "-builtin/git-workflow"
          "-external/*"
        ];
        modules.ai.skills.extra."external/cpp-coroutines" = replacement;
      }
    ];
    empty = home [ { modules.ai.skills.select = lib.mkForce [ ]; } ];
  };
  disabled = home [ { modules.ai.omp.enable = false; } ];
  require = label: condition: if condition then true else throw "omp-skills check failed: ${label}";
  checks = [
    (require "disabled OMP has no config activation" (!(disabled.config.home.activation ? ompConfig)))
    (require "disabled OMP has no injected discovery path" (
      disabled.config.programs.omp.settings.skills.customDirectories == [ (toString callerSkills) ]
    ))
  ]
  ++ lib.mapAttrsToList (
    name: result:
    require "${name} does not own the native user skill directory" (
      lib.all (
        file:
        !(lib.hasPrefix ".omp/agent/skills" (
          lib.removePrefix "${result.config.home.homeDirectory}/" file.target
        ))
      ) (builtins.attrValues result.config.home.file)
    )
  ) cases;
  activations = lib.mapAttrs (
    name: result:
    pkgs.writeShellScript "omp-skills-${name}-activate" ''
      set -euo pipefail
      run() { "$@"; }
      ${result.config.home.activation.ompConfig.data}
    ''
  ) cases;
  python = pkgs.python3.withPackages (packages: [ packages.pyyaml ]);
in
assert lib.all (check: check) checks;
pkgs.runCommand "omp-skills-discovery-checks"
  {
    nativeBuildInputs = [ python ];
  }
  ''
    set -euo pipefail
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: result: ''
          export HOME="$TMPDIR/${name}/home"
          export PI_CODING_AGENT_DIR="$HOME/.omp/agent"
          unset PI_PROFILE XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
          mkdir -p "$PI_CODING_AGENT_DIR/skills" "$TMPDIR/${name}/project"
          cp -R ${nativeSkills}/native-only "$PI_CODING_AGENT_DIR/skills/"
          ${activations.${name}}
          ${lib.getExe result.config.programs.omp.package} skill list "$TMPDIR/${name}/project" --json > "$TMPDIR/${name}/discovered.json"
          python - ${lib.escapeShellArg (toString result.config.modules.ai.skillsSource)} "$TMPDIR/${name}/discovered.json" <<'PY'
        import json
        import os
        import sys
        from pathlib import Path
        import yaml

        selected = Path(sys.argv[1])
        discovered = json.loads(Path(sys.argv[2]).read_text())["skills"]
        expected = {path.parent.name for path in selected.glob("*/SKILL.md")}
        actual = {skill["name"] for skill in discovered}
        assert actual == expected | {"caller-only", "native-only"}, (expected, discovered)
        for skill in discovered:
            if skill["name"] in expected:
                assert Path(skill["filePath"]).resolve() == (selected / skill["name"] / "SKILL.md").resolve(), skill
        config = yaml.safe_load((Path(os.environ["PI_CODING_AGENT_DIR"]) / "config.yml").read_text())
        assert config["skills"]["customDirectories"] == ["${callerSkills}", str(selected)], config
        assert config["startup"]["quiet"] is True, config
        assert config["theme"]["light"] == "caller-theme", config
        assert (Path(os.environ["PI_CODING_AGENT_DIR"]) / "skills/native-only/SKILL.md").is_file()
        PY
      '') cases
    )}
    touch "$out"
  ''
