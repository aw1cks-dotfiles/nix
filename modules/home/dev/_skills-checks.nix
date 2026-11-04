{
  inputs,
  lib,
  pkgs,
  aiModule,
}:
let
  fixtureInputs = inputs // {
    intel-performance-skills = ./_skills-fixtures/intel;
    low-level-dev-skills = ./_skills-fixtures/lowlevel;
  };
  skills = import ./_skills.nix {
    inputs = fixtureInputs;
    inherit lib pkgs;
  };
  duplicateSkills = import ./_skills.nix {
    inputs = fixtureInputs // {
      low-level-dev-skills = ./_skills-fixtures/duplicates;
    };
    inherit lib pkgs;
  };
  replacement = ./_skills-fixtures/extra/cpp-coroutines;
  names = args: builtins.attrNames (skills.resolve args);
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  require = label: condition: if condition then true else throw "agent-skills check failed: ${label}";

  # Evaluate the actual public module, including its normal list/path merge types.
  home =
    modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.hostFacts = { };
      modules = [
        inputs.oh-my-pi.homeManagerModules.default
        aiModule
        {
          home.username = "skills-check";
          home.homeDirectory = "/build/skills-check";
          home.stateVersion = "25.05";
          home.packages = lib.mkForce [ ];
          modules.ai.omp = {
            enable = false;
            package = pkgs.hello;
          };
          modules.ai.mcp = {
            enable = false;
          };
        }
      ]
      ++ modules;
    };
  layered = home [ { modules.ai.skills.select = [ "intel/linux-perf" ]; } ];
  cleared = home [ { modules.ai.skills.select = lib.mkForce [ ]; } ];
  defaultHome = home [ ];
  conflictingExtras = home [
    { modules.ai.skills.extra."external/cpp-coroutines" = replacement; }
    { modules.ai.skills.extra."external/cpp-coroutines" = ./_skills-fixtures/intel/skills/fixture; }
  ];
  forcedExtra = home [
    { modules.ai.skills.extra."external/cpp-coroutines" = ./_skills-fixtures/intel/skills/fixture; }
    { modules.ai.skills.extra."external/cpp-coroutines" = lib.mkForce replacement; }
  ];
  checks = [
    (require "helper selection is opt-in" (names { } == [ ]))
    (require "unselected basename collisions coexist" (
      names { select = [ "intel/*" ]; } == [ "intel/fixture" ]
    ))
    (require "selected basename collision fails" (
      fails (names {
        select = [ "*/fixture" ];
      })
    ))
    (require "exclusion removes collisions before validation" (
      names {
        select = [
          "-lowlevel/*"
          "*/fixture"
        ];
      } == [ "intel/fixture" ]
    ))
    (require "exclusions win regardless of order" (
      names {
        select = [
          "lowlevel/*"
          "-lowlevel/fixture"
        ];
      } == names {
        select = [
          "-lowlevel/fixture"
          "lowlevel/*"
        ];
      }
    ))
    (require "partial component wildcard matches" (
      names {
        select = [ "int*/fix*" ];
      } == [ "intel/fixture" ]
    ))
    (require "exclusions also remove automatically included extras" (
      names {
        extra."external/cpp-coroutines" = replacement;
        select = [ "-external/*" ];
      } == [ ]
    ))
    (require "unknown positive fails even beside valid selection" (
      fails (names {
        select = [
          "builtin/*"
          "intel/missing"
        ];
      })
    ))
    (require "unmatched negative is nonfatal" (
      names {
        select = [
          "intel/*"
          "-external/missing"
        ];
      } == [ "intel/fixture" ]
    ))
    (require "invalid extra traversal fails" (
      fails (names {
        extra."external/../escape" = replacement;
      })
    ))
    (require "invalid wildcard fails" (
      fails (names {
        select = [ "intel/**" ];
      })
    ))
    (require "duplicate discovered ID fails even when unselected" (
      fails (builtins.attrNames (duplicateSkills.resolve { }))
    ))
    (require "build whitelist and profiler/category policy apply" (
      names { select = [ "lowlevel/*" ]; } == [
        "lowlevel/cmake"
        "lowlevel/cpp-coroutines"
        "lowlevel/fixture"
        "lowlevel/strace-ltrace"
      ]
    ))
    (require "conflicting ordinary extra definitions fail" (
      fails conflictingExtras.config.modules.ai.skills.extra
    ))
    (require "mkForce replaces conflicting extra definition" (
      forcedExtra.config.modules.ai.skills.extra."external/cpp-coroutines" == replacement
    ))
    (require "skillsSource cannot be independently assigned" (
      fails (home [ { modules.ai.skillsSource = replacement; } ]).config.modules.ai.skillsSource
    ))
  ];
  assembled = skills.build {
    select = [
      "intel/*"
      "lowlevel/cmake"
    ];
  };
  replaced = skills.build { extra."lowlevel/cpp-coroutines" = replacement; };
  excludedExtra = skills.build {
    select = [ "-lowlevel/*" ];
    extra."lowlevel/cpp-coroutines" = replacement;
  };
  invalidBuilders = lib.genAttrs [ "mismatch" "malformed" "missing" ] (
    name:
    let
      invalid = skills.build { extra."external/${name}" = ./_skills-fixtures/invalid + "/${name}"; };
    in
    pkgs.writeShellScript "reject-invalid-skill-${name}" ''
      set -euo pipefail
      ${invalid.buildCommand}
    ''
  );
in
assert lib.all (check: check) checks;
pkgs.runCommand "agent-skills-checks" { } ''
  ${pkgs.python3}/bin/python - <<'PY'
  import json
  import os
  from pathlib import Path
  import subprocess
  import tempfile

  assembled = Path("${assembled}")
  assert sorted(path.name for path in assembled.iterdir()) == ["cmake", "fixture"]
  fixture = assembled / "fixture"
  assert (fixture / "references/note.txt").read_text() == "retained reference\n"
  assert os.access(fixture / "scripts/probe", os.X_OK)
  assert (fixture / ".upstream-license/COPYRIGHT.md").read_bytes() == Path(
      "${./_skills-fixtures/intel/COPYRIGHT.md}"
  ).read_bytes()
  for notice in ["LICENSE", "NOTICE"]:
      assert (assembled / "cmake/.upstream-license" / notice).read_bytes() == (
          Path("${./_skills-fixtures/lowlevel}") / notice
      ).read_bytes()

  replaced = Path("${replaced}") / "cpp-coroutines"
  assert (replaced / "references/replacement.txt").read_text() == "only replacement reference\n"
  assert not (replaced / "bundled-only.txt").exists()
  assert not (replaced / ".upstream-license").exists()
  assert list(Path("${excludedExtra}").iterdir()) == []

  # These are assembled public module outputs, not copies of option defaults.
  baseline = sorted(path.name for path in Path("${defaultHome.config.modules.ai.skillsSource}").iterdir())
  assert baseline == ["context7", "git-workflow"]
  layered = sorted(path.name for path in Path("${layered.config.modules.ai.skillsSource}").iterdir())
  assert layered == sorted(baseline + ["linux-perf"])
  assert list(Path("${cleared.config.modules.ai.skillsSource}").iterdir()) == []

  builders = json.loads(${builtins.toJSON (builtins.toJSON invalidBuilders)})
  with tempfile.TemporaryDirectory() as temporary:
      for name, builder in builders.items():
          result = subprocess.run(
              [builder],
              env={**os.environ, "out": str(Path(temporary) / name)},
              capture_output=True,
              text=True,
              check=False,
          )
          assert result.returncode != 0, f"invalid skill {name} was accepted"
  PY
  touch "$out"
''
