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
    xdg = home [ { modules.ai.omp.storage = "xdg"; } ];
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
  unmanagedTheme = home [
    {
      programs.omp.settings = lib.mkForce (
        cases.default.config.programs.omp.settings
        // {
          theme = builtins.removeAttrs cases.default.config.programs.omp.settings.theme [ "light" ];
        }
      );
    }
  ];
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
  unmanagedThemeActivation = pkgs.writeShellScript "omp-skills-unmanaged-theme-activate" ''
    set -euo pipefail
    run() { "$@"; }
    ${unmanagedTheme.config.home.activation.ompConfig.data}
  '';
in
assert lib.all (check: check) checks;
pkgs.runCommand "omp-skills-discovery-checks"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    set -euo pipefail
    python3 - <<'PY'
    import json
    import os
    from pathlib import Path
    import shutil
    import subprocess

    root = Path(os.environ["TMPDIR"]).resolve()
    for name, executable, activation, selected_path in [
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: result: ''
        (${builtins.toJSON name}, "${lib.getExe result.config.programs.omp.package}", "${activations.${name}}", "${result.config.modules.ai.skillsSource}"),
      '') cases
    )}
    ]:
        home = root / name / "home"
        agent = home / ".omp/agent"
        project = root / name / "project"
        project.mkdir(parents=True)
        (agent / "skills").mkdir(parents=True)
        shutil.copytree("${nativeSkills}/native-only", agent / "skills/native-only")
        native_skill = agent / "skills/native-only/SKILL.md"
        original_skill = native_skill.read_bytes()
        if name == "xdg":
            relocated = home / ".config/omp/agent"
            refused_launch = subprocess.run([executable, "--version"], env={"HOME": str(home), "PATH": os.environ["PATH"]}, cwd=project, capture_output=True)
            assert refused_launch.returncode != 0
            assert not relocated.exists()
            relocated.parent.mkdir(parents=True)
            agent.rename(relocated)
            agent = relocated
            native_skill = agent / "skills/native-only/SKILL.md"
        # Existing global values are preserved, even when shadowed by Nix.
        original_config = '{"theme": {"light": "stale"}, "startup": {"showSplash": false}}\n'
        (agent / "config.yml").write_text(original_config)
        env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("PI_", "OMP_", "XDG_"))
            and key not in {"HOME", "CLAUDE_CONFIG_DIR"}
        }
        env.update(
            HOME=str(home),
            XDG_CONFIG_HOME=str(home / ".config"),
            XDG_DATA_HOME=str(home / ".local/share"),
            XDG_STATE_HOME=str(home / ".local/state"),
            XDG_CACHE_HOME=str(home / ".cache"),
            PI_NATIVES_DIR=str(home / ".cache/omp/natives"),
            OMP_WORKTREE_DIR=str(home / ".omp/wt"),
        )

        def activate(script=activation):
            subprocess.run([script], env=env, cwd=project, check=True)

        def omp(*args, package=executable):
            result = subprocess.run(
                [package, *args, "--json"], env=env, cwd=project,
                check=True, capture_output=True, text=True,
            )
            return json.loads(result.stdout)

        def value(key, package=executable):
            return omp("config", "get", key, package=package)["value"]

        activate()
        discovered = omp("skill", "list", str(project))["skills"]
        selected = Path(selected_path)
        expected = {path.parent.name for path in selected.glob("*/SKILL.md")}
        actual = {skill["name"] for skill in discovered}
        assert actual == expected | {"caller-only", "native-only"}, (expected, discovered)
        for skill in discovered:
            if skill["name"] in expected:
                assert Path(skill["filePath"]).resolve() == (selected / skill["name"] / "SKILL.md").resolve(), skill
        assert value("skills.customDirectories") == ["${callerSkills}", str(selected)]
        assert value("startup.quiet") is True
        assert value("theme.light") == "caller-theme"
        assert (agent / "config.yml").read_text() == original_config
        assert value("startup.showSplash") is False
        global_config = omp("config", "list", "--scope", "global")
        assert global_config["theme.light"]["value"] == "stale", global_config
        assert "skills.customDirectories" not in global_config, global_config
        assert "startup.quiet" not in global_config, global_config

        # CLI writes use the writable global layer, not the immutable declarations.
        omp("config", "set", "startup.showSplash", "true")
        omp("config", "set", "theme.light", "light")
        assert value("theme.light") == "caller-theme"
        global_config = omp("config", "list", "--scope", "global")
        assert global_config["theme.light"]["value"] == "light", global_config
        assert global_config["startup.showSplash"]["value"] is True, global_config
        saved_config = (agent / "config.yml").read_bytes()
        activate()
        assert (agent / "config.yml").read_bytes() == saved_config
        # Each query launches a new packaged process after the second activation.
        assert value("startup.showSplash") is True
        assert value("theme.light") == "caller-theme"
        assert native_skill.read_bytes() == original_skill

        if name == "default":
            # Removing a declaration exposes the global value instead of retaining
            # the old managed value in the writable main configuration.
            unmanaged = "${lib.getExe unmanagedTheme.config.programs.omp.package}"
            assert value("theme.light", package=unmanaged) == "light"
            activate("${unmanagedThemeActivation}")
            assert value("theme.light", package=unmanaged) == "light"
            assert value("startup.showSplash", package=unmanaged) is True
            # A child can inherit an older Nix generation's overlay. It must
            # not shadow the new generation, but explicit caller overlays win.
            caller_overlay = home / "caller.yml"
            caller_overlay.write_text('{"startup": {"quiet": false}}')
            env["PI_CONFIG_FILES"] = "${cases.default.config.programs.omp.package.managedSettings}:" + str(caller_overlay)
            assert value("theme.light", package=unmanaged) == "light"
            assert value("startup.quiet", package=unmanaged) is False
            env.pop("PI_CONFIG_FILES")
            assert native_skill.read_bytes() == original_skill
    PY
    touch "$out"
  ''
