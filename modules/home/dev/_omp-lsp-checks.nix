{
  inputs,
  lib,
  pkgs,
  aiModule,
}:
let
  home =
    modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.hostFacts = { };
      modules = [
        inputs.oh-my-pi.homeManagerModules.default
        aiModule
        {
          home.username = "omp-lsp-check";
          home.homeDirectory = "/build/omp-lsp-check";
          home.stateVersion = "25.05";
          home.packages = lib.mkForce [ ];
          modules.ai.mcp.enable = false;
          modules.ai.omp.settings.startup.quiet = true;
        }
      ]
      ++ modules;
    };
  generated =
    result: builtins.fromJSON (builtins.readFile result.config.home.file.".omp/agent/lsp.json".source);
  defaultHome = home [ ];
  disabledHome = home [
    {
      modules.ai.omp.lspServers = {
        rust-analyzer.disabled = true;
        taplo.disabled = true;
      };
    }
  ];
  defaults = generated defaultHome;
  overridden = generated (home [
    {
      modules.ai.omp.lspServers = {
        taplo.args = [
          "lsp"
          "stdio"
          "--colors"
          "never"
        ];
        sqls = {
          command = "sqls";
          fileTypes = [ ".sql" ];
          rootMarkers = [ "*.sql" ];
        };
        jdtls = {
          command = "jdtls";
          fileTypes = [ ".java" ];
        };
      };
    }
  ]);
  require = label: condition: if condition then true else throw "omp-lsp check failed: ${label}";
  probe = pkgs.writeText "omp-lsp-config-probe.ts" ''
    import assert from "node:assert/strict";
    import { existsSync } from "node:fs";
    import path from "node:path";
    import { loadConfig } from "@oh-my-pi/pi-coding-agent/lsp/config";

    export default function (pi) {
      pi.on("session_start", () => {
        setTimeout(() => {
          try {
            const servers = loadConfig(process.env.PROBE_PROJECT).servers;
            const enabled = process.env.PROBE_ENABLED === "true";
            for (const name of ["rust-analyzer", "taplo"]) {
              assert.equal(Object.hasOwn(servers, name), enabled,
                name + (enabled ? " must be eligible" : " must be suppressed"));
            }
            if (enabled) {
              const composeRoot = process.env.PROBE_COMPOSE_ROOT;
              for (const marker of [
                "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
              ]) {
                const cwd = path.join(composeRoot, marker);
                assert.equal(existsSync(path.join(cwd, ".git")), false);
                const yaml = loadConfig(cwd).servers.yamlls;
                assert.ok(yaml, marker + " must select yamlls without .git");
              }
              assert.ok(loadConfig(path.join(composeRoot, "git-yaml")).servers.yamlls,
                "ordinary YAML in a Git root must remain eligible");
              assert.equal(Object.hasOwn(loadConfig(path.join(composeRoot, "plain-yaml")).servers, "yamlls"),
                false, "ordinary standalone YAML must not broaden root eligibility");
            }
            console.log("OMP LSP Compose and " + (enabled ? "eligibility" : "suppression") + " passed");
            process.exit(0);
          } catch (error) {
            console.error(error);
            process.exit(1);
          }
        }, 0);
      });
    }
  '';
  checks = [
    (require "shared defaults are written" (defaults.servers.taplo.command == "taplo"))
    (require "built-in overrides are complete definitions" (
      defaults.servers.omnisharp == { command = "OmniSharp"; }
    ))
    (require "kotlin argv replaces the built-in --stdio flag" (
      defaults.servers."kotlin-lsp".args == [ ]
    ))
    (require "per-key overrides keep the rest of the entry" (
      overridden.servers.taplo == {
        command = "taplo";
        args = [
          "lsp"
          "stdio"
          "--colors"
          "never"
        ];
        fileTypes = [ ".toml" ];
        rootMarkers = [ "*.toml" ];
      }
    ))
    (require "sqls is opt-in" (!(defaults.servers ? sqls) && overridden.servers.sqls.command == "sqls"))
    (require "new servers are appended" (overridden.servers ? jdtls))
    (require "arrays replace instead of concatenating" (
      overridden.servers.sqls.fileTypes == [ ".sql" ]
    ))
  ];
in
assert lib.all (check: check) checks;
pkgs.runCommand "omp-lsp-config-check"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.rust-analyzer
      pkgs.taplo
      pkgs.yaml-language-server
    ];
  }
  ''
    python3 - <<'PY'
    import os
    from pathlib import Path
    import shutil
    import subprocess

    root = Path(os.environ["TMPDIR"]).resolve()
    project = root / "project"
    project.mkdir()
    (project / "Cargo.toml").write_text('[package]\nname = "probe"\nversion = "0.1.0"\n')
    compose_root = root / "compose"
    compose_root.mkdir()
    for marker in ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]:
        standalone = compose_root / marker
        standalone.mkdir()
        (standalone / marker).write_text("services: {}\n")
    for name in ["git-yaml", "plain-yaml"]:
        yaml_project = compose_root / name
        yaml_project.mkdir()
        (yaml_project / "config.yaml").write_text("key: value\n")
    (compose_root / "git-yaml" / ".git").mkdir()
    for name, source, enabled in [
        ("default", "${defaultHome.config.home.file.".omp/agent/lsp.json".source}", "true"),
        ("disabled", "${disabledHome.config.home.file.".omp/agent/lsp.json".source}", "false"),
    ]:
        home = root / name
        agent = home / ".omp/agent"
        agent.mkdir(parents=True)
        shutil.copyfile(source, agent / "lsp.json")
        env = os.environ.copy()
        for key in [
            "PI_CONFIG_DIR", "PI_PROFILE", "OMP_PROFILE", "CLAUDE_CONFIG_DIR",
            "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME",
        ]:
            env.pop(key, None)
        env.update(
            HOME=str(home),
            PI_CODING_AGENT_DIR=str(agent),
            PROBE_PROJECT=str(project),
            PROBE_ENABLED=enabled,
            PROBE_COMPOSE_ROOT=str(compose_root),
            OPENAI_API_KEY="smoke-not-a-real-key",
        )
        # Keep stdin open until the extension exits; EOF shuts down RPC first.
        read_fd, write_fd = os.pipe()
        try:
            result = subprocess.run(
                [
                    "${lib.getExe defaultHome.config.programs.omp.package}",
                    "--mode", "rpc", "--no-ui", "--no-session", "--no-extensions",
                    "--no-skills", "--no-rules", "--no-context-files", "--tools", "lsp",
                    "--model", "openai/gpt-5.2", "--cwd", str(project), "-e", "${probe}",
                ],
                env=env, stdin=read_fd, capture_output=True, text=True, timeout=60,
            )
        finally:
            os.close(read_fd)
            os.close(write_fd)
        if result.returncode:
            print(result.stdout, end="")
        print(result.stderr, end="")
        result.check_returncode()
        for line in result.stdout.splitlines():
            if line.startswith("OMP LSP "):
                print(line)
    PY
    touch "$out"
  ''
