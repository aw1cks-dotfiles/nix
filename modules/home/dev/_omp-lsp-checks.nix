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
  xdgHome = home [ { modules.ai.omp.storage = "xdg"; } ];
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
    import { resolveActiveProjectRegistryPath, resolveOrDefaultProjectRegistryPath } from "@oh-my-pi/pi-coding-agent/discovery/helpers";
    import { loadCapability } from "@oh-my-pi/pi-coding-agent/discovery";
    import { mcpCapability } from "@oh-my-pi/pi-coding-agent/capability/mcp";

    export default function (pi) {
      pi.on("session_start", () => {
        setTimeout(async () => {
          try {
            if (process.env.PROBE_XDG === "true") {
              const expected = path.join(process.env.PROBE_PROJECT, ".omp/plugins/installed_plugins.json");
              assert.equal(await resolveActiveProjectRegistryPath(process.env.PROBE_PROJECT), expected);
              assert.equal(await resolveOrDefaultProjectRegistryPath(process.env.PROBE_PROJECT), expected);
              assert.equal(await resolveOrDefaultProjectRegistryPath(process.env.PROBE_EMPTY_PROJECT),
                path.join(process.env.PROBE_EMPTY_PROJECT, ".omp/plugins/installed_plugins.json"));
              const mcp = await loadCapability(mcpCapability.id, { cwd: process.env.PROBE_PROJECT });
              assert.ok(mcp.items.some(server => server.name === "authored-relocated"),
                "relocated MCP config must be discovered even when disabled");
            }
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
    (project / ".omp/plugins").mkdir(parents=True)
    (project / ".omp/plugins/installed_plugins.json").write_text('{"version": 1, "plugins": {}}')
    empty_project = root / "empty-project"
    empty_project.mkdir()
    for name, source, enabled, executable in [
        ("default", "${
          defaultHome.config.home.file.".omp/agent/lsp.json".source
        }", "true", "${lib.getExe defaultHome.config.programs.omp.package}"),
        ("disabled", "${
          disabledHome.config.home.file.".omp/agent/lsp.json".source
        }", "false", "${lib.getExe disabledHome.config.programs.omp.package}"),
        ("xdg", "${
          xdgHome.config.home.file.".config/omp/agent/lsp.json".source
        }", "true", "${lib.getExe xdgHome.config.programs.omp.package}"),
    ]:
        home = root / name
        agent = home / (".config/omp/agent" if name == "xdg" else ".omp/agent")
        agent.mkdir(parents=True)
        shutil.copyfile(source, agent / "lsp.json")
        (agent / "mcp.json").write_text('{"mcpServers":{"authored-relocated":{"command":"${pkgs.coreutils}/bin/false","enabled":false}}}')
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
            PROBE_PROJECT=str(project),
            PROBE_ENABLED=enabled,
            PROBE_XDG="true" if name == "xdg" else "false",
            PROBE_EMPTY_PROJECT=str(empty_project),
            PROBE_COMPOSE_ROOT=str(compose_root),
            OPENAI_API_KEY="smoke-not-a-real-key",
        )
        # Keep stdin open until the extension exits; EOF shuts down RPC first.
        read_fd, write_fd = os.pipe()
        try:
            result = subprocess.run(
                [
                    executable,
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
