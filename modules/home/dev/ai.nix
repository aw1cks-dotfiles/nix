# AI coding tools — from nix-upstream/modules/development/ai.nix
{ inputs, ... }:
{
  aw1cks.modules.home.ai =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.modules.ai;
      skills = import ./_skills.nix { inherit inputs lib pkgs; };
      lspDefaults = import ./files/agents/omp/_lsp.nix;
      mkModelTierOption =
        {
          description,
          model,
        }:
        lib.mkOption {
          type = lib.types.str;
          default = model;
          inherit description;
        };
      frontier_model = cfg.models.frontier;
      premium_model = cfg.models.premium;
      standard_model = cfg.models.standard;
      small_model = cfg.models.small;
    in
    {
      options.modules.ai = {
        models = lib.mkOption {
          type = lib.types.submodule {
            options = {
              frontier = mkModelTierOption {
                description = "Frontier model used for the most demanding planning and review tasks.";
                model = "openai-codex/gpt-6-astra:xhigh";
              };
              premium = mkModelTierOption {
                description = "Premium model used for primary interactive work.";
                model = "openai-codex/gpt-6.1-sol:high";
              };
              standard = mkModelTierOption {
                description = "Standard model used for general delegated work.";
                model = "openai-codex/gpt-6.1-sol:medium";
              };
              small = mkModelTierOption {
                description = "Small model used for exploration and lightweight background work.";
                model = "openai-codex/gpt-6-luna:low";
              };
            };
          };
          default = { };
          description = "Model tiers feeding the shared OMP defaults; values are OMP model selectors with an optional thinking suffix.";
        };

        mcp = lib.mkOption {
          type = lib.types.anything;
          description = "MCP home-manager configuration";

          default = {
            enable = true;
            servers = {
              context7 = {
                url = "https://mcp.context7.com/mcp";
                headers = {
                  CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}";
                };
              };
            };
          };
        };

        skills = {
          select = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Agent skill IDs or component-local '*' selectors; exclusions prefixed with '-' take precedence.";
          };
          extra = lib.mkOption {
            type = lib.types.attrsOf lib.types.path;
            default = { };
            description = "Additional whole skill directories keyed by namespace/name, replacing bundled IDs completely.";
          };
        };

        skillsSource = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          description = "Derived flat directory of selected agent skills, exposed for downstream consumers.";
        };

        omp = lib.mkOption {
          type = lib.types.submoduleWith {
            shorthandOnlyDefinesConfig = true;
            # Pass pkgs explicitly: submodule modules resolve unset args via
            # `_module.args`, which needs the outer config fixpoint and recurses
            # when the option is forced from config evaluation.
            specialArgs = { inherit pkgs; };
            modules = [
              (
                { lib, pkgs, ... }:
                {
                  freeformType = lib.types.attrsOf lib.types.anything;
                  options = {

                    extraMcpConfig = lib.mkOption {
                      type = lib.types.nullOr lib.types.path;
                      default = null;
                      description = "Optional base OMP mcp.json file merged beneath programs.mcp.servers.";
                    };
                    disabledMcpServers = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      description = "MCP server names written to disabledServers in ~/.omp/agent/mcp.json.";
                    };
                    lspServers = lib.mkOption {
                      type = lib.types.attrsOf lib.types.anything;
                      default = { };
                      description = ''
                        OMP LSP server definitions merged per server name over the
                        shared defaults in files/agents/omp/_lsp.nix and written to
                        ~/.omp/agent/lsp.json. Keys override individual fields of
                        an entry; set `disabled = true` to suppress one, including
                        built-in servers.
                      '';
                    };
                  };

                  config = {
                    enable = lib.mkDefault true;
                    # Build with OMP's own pinned Rust toolchain. The
                    # llm-agents overlay uses stable rustc, but OMP uses
                    # unstable standard-library APIs.
                    package = lib.mkDefault inputs.oh-my-pi.packages.${pkgs.stdenv.hostPlatform.system}.omp;

                    # Per-key defaults: a downstream `settings` attrset merges
                    # key-by-key (last one wins per key) instead of replacing
                    # this whole block, so private overlays can override the
                    # model routing without restating shared UI preferences.
                    settings = {
                      # State markers: without these every switch re-runs
                      # onboarding and re-prompts for dev consent.
                      setupVersion = lib.mkDefault 2;
                      dev.autoqaConsent = lib.mkDefault "granted";

                      theme.dark = lib.mkDefault "oxocarbon-dark";
                      composer.shape = lib.mkDefault "rail";
                      statusLine = lib.mkDefault {
                        preset = "nerd";
                        contextLine = "percentage";
                      };
                      display = lib.mkDefault {
                        cacheMissMarker = true;
                        showTurnTime = true;
                        showTokenUsage = true;
                      };
                      tui.tight = lib.mkDefault true;
                      terminal.showProgress = lib.mkDefault true;
                      # Pin reasoning effort instead of auto to prevent mid-session
                      # thinking_level_change events from busting prompt caches.
                      defaultThinkingLevel = lib.mkDefault "high";
                      extendedContext = lib.mkDefault true;
                      advisor.enabled = lib.mkDefault false;
                      recap.enabled = lib.mkDefault false;
                      provider.appendOnlyContext = lib.mkDefault "on";
                      tools.approvalMode = lib.mkDefault "write";
                      tools.xdev = lib.mkDefault true;
                      tools.xdevDocs = lib.mkDefault "builtins";
                      github.enabled = lib.mkDefault true;
                      astGrep.enabled = lib.mkDefault true;

                      # The lsp tool's per-call deadline is
                      # max(20, lsp.requestTimeout); rust-analyzer needs more than
                      # the 20s floor on a cold, large workspace. Measured on this
                      # checkout: warm hover ~6s, cold symbols ~35s. The value is
                      # also the ceiling for post-edit diagnostics, but the write
                      # path does not block on it: a healthy server returns in
                      # ~3s, and a server that never reports costs the same at 10
                      # and 60 because a 25s floor dominates. Per-call `timeout=`
                      # still overrides this in either direction.
                      lsp.requestTimeout = lib.mkDefault 60;

                      # Use OMP's built-in 10-rule DEFAULT_BASH_INTERCEPTOR_RULES
                      # (cat/head/tail, grep/rg, find/fd, sed -i, perl -i, awk, echo >, nohup).
                      bashInterceptor.enabled = lib.mkDefault true;

                      edit = {
                        mode = lib.mkDefault "hashline";
                        autoRepair.enabled = lib.mkDefault true;
                        modelVariants = lib.mkDefault {
                          glm = "replace";
                          qwen = "replace";
                          deepseek = "replace";
                          kimi = "replace";
                        };
                      };

                      compaction = {
                        methodOrder = lib.mkDefault [
                          "remote"
                          "handoff"
                          "shake"
                          "soft"
                        ];
                        idleEnabled = lib.mkDefault false;
                        idleThresholdTokens = lib.mkDefault 160000;
                        idleTimeoutSeconds = lib.mkDefault 240;
                        handoffSaveToDisk = lib.mkDefault true;
                      };

                      prewalk = {
                        enabled = lib.mkDefault false;
                        autoTarget = lib.mkDefault "@task";
                      };
                      bash.allowCompoundCommands = lib.mkDefault true;
                      # Keep privilege escalation gated, including in yolo
                      # sessions. Auto-approve only explicit, read-only Git
                      # forms; broad subcommands such as `git branch *` also
                      # include mutating operations.
                      bash.patterns = lib.mkDefault [
                        {
                          match = "sudo *";
                          approval = "prompt";
                        }
                        {
                          match = "git status";
                          approval = "allow";
                        }
                        {
                          match = "git status --short";
                          approval = "allow";
                        }
                        {
                          match = "git status --short --branch";
                          approval = "allow";
                        }
                        {
                          match = "git status --porcelain";
                          approval = "allow";
                        }
                        {
                          match = "git status --porcelain=v1";
                          approval = "allow";
                        }
                        {
                          match = "git status --porcelain=v2";
                          approval = "allow";
                        }
                        {
                          match = "git diff --no-ext-diff --no-textconv";
                          approval = "allow";
                        }
                        {
                          match = "git diff --no-ext-diff --no-textconv -- *";
                          approval = "allow";
                        }
                        {
                          match = "git diff --cached --no-ext-diff --no-textconv";
                          approval = "allow";
                        }
                        {
                          match = "git diff --cached --no-ext-diff --no-textconv -- *";
                          approval = "allow";
                        }
                        {
                          match = "git diff --check";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --show-toplevel";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --is-inside-work-tree";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --abbrev-ref HEAD";
                          approval = "allow";
                        }
                        {
                          match = "git rev-parse --verify *";
                          approval = "allow";
                        }
                        {
                          match = "git merge-base *";
                          approval = "allow";
                        }
                        {
                          match = "git branch --show-current";
                          approval = "allow";
                        }
                        {
                          match = "git branch --list";
                          approval = "allow";
                        }
                        {
                          match = "git branch --list *";
                          approval = "allow";
                        }
                        {
                          match = "git branch -r";
                          approval = "allow";
                        }
                        {
                          match = "git symbolic-ref --short HEAD";
                          approval = "allow";
                        }
                        {
                          match = "git symbolic-ref refs/remotes/origin/HEAD";
                          approval = "allow";
                        }
                        {
                          match = "git log";
                          approval = "allow";
                        }
                        {
                          match = "git log --oneline";
                          approval = "allow";
                        }
                        {
                          match = "git log --oneline --decorate";
                          approval = "allow";
                        }
                        {
                          match = "git log --oneline --decorate --graph --all";
                          approval = "allow";
                        }
                        {
                          match = "git show --no-ext-diff --no-textconv";
                          approval = "allow";
                        }
                        {
                          match = "git ls-files";
                          approval = "allow";
                        }
                        {
                          match = "git ls-files -- *";
                          approval = "allow";
                        }
                        {
                          match = "git worktree list";
                          approval = "allow";
                        }
                        {
                          match = "git remote";
                          approval = "allow";
                        }
                        {
                          match = "git remote -v";
                          approval = "allow";
                        }
                        {
                          match = "git remote get-url *";
                          approval = "allow";
                        }
                        {
                          match = "git config --get *";
                          approval = "allow";
                        }
                        {
                          match = "git config --get-all *";
                          approval = "allow";
                        }
                        {
                          match = "git config --get-regexp *";
                          approval = "allow";
                        }
                      ];

                      modelRoles = lib.mkDefault {
                        default = premium_model;
                        smol = small_model;
                        slow = frontier_model;
                        vision = standard_model;
                        plan = frontier_model;
                        designer = premium_model;
                        commit = small_model;
                        tiny = small_model;
                        task = standard_model;
                        advisor = frontier_model;
                      };

                      # Per-subkey defaults so a downstream `task.isolation.*`
                      # choice merges instead of replacing this block.
                      task.isolation.mode = lib.mkDefault "auto";
                      task.maxRecursionDepth = lib.mkDefault 1;
                      task.prewalk = lib.mkDefault false;
                      task.softRequestBudget = lib.mkDefault 50;
                      task.agentSoftRequestBudget = lib.mkDefault {
                        reviewer = 12;
                        security-reviewer = 15;
                        scout = 20;
                        task = 40;
                      };
                      task.agentModelOverrides = lib.mkDefault {
                        # Permit one layer of delegation and strip task spawning
                        # from those child agents.
                        scout = "@smol";
                        librarian = "@smol";
                        sonic = "@smol";
                        task = "@task";
                        designer = "@designer";
                        reviewer = "@slow";
                        security-reviewer = "@slow";
                      };
                    };
                  };
                }
              )
            ];
          };
          default = { };
          description = "OMP home-manager configuration.";
        };
      };

      config = {
        modules.ai.skills.select = skills.defaultSelect;
        modules.ai.skillsSource = skills.build cfg.skills;

        home.packages = with pkgs.llm-agents; [
          claude-code
        ];

        programs.mcp = cfg.mcp;
        programs.omp = lib.mkMerge [
          (builtins.removeAttrs cfg.omp [
            "extraMcpConfig"
            "disabledMcpServers"
            "lspServers"
          ])
          (lib.mkIf config.programs.omp.enable {
            # OMP scans these alongside native user/project skills. Do not own
            # ~/.omp/agent/skills: it also contains users' locally authored skills.
            settings.skills.customDirectories = lib.mkAfter [ (toString cfg.skillsSource) ];
          })
        ];
        home.file = lib.mkIf cfg.omp.enable (
          {
            ".omp/agent/themes/oxocarbon-dark.json".source = ./files/agents/omp/themes/oxocarbon-dark.json;
            ".omp/agent/lsp.json".source =
              let
                # OMP merges each server as `{ ...builtin, ...override }`: keys are
                # shallow-merged and arrays replaced wholesale. Mirror that here so
                # the generated file and OMP's own merge can never disagree.
                merged = lib.mapAttrs (name: override: (lspDefaults.${name} or { }) // override) cfg.omp.lspServers;
                servers = lspDefaults // merged;
              in
              pkgs.writeText "omp-lsp.json" (builtins.toJSON { inherit servers; });
          }
          //
            lib.optionalAttrs
              (
                cfg.omp.extraMcpConfig != null || (config.programs.mcp.enable && config.programs.mcp.servers != { })
              )
              {
                ".omp/agent/mcp.json".source =
                  let
                    hmServersJson = pkgs.writeText "hm-mcp-servers.json" (
                      builtins.toJSON (if config.programs.mcp.enable then config.programs.mcp.servers else { })
                    );
                    disabledJson = pkgs.writeText "omp-disabled-mcps.json" (builtins.toJSON cfg.omp.disabledMcpServers);
                    baseMcpPath = if cfg.omp.extraMcpConfig != null then "${cfg.omp.extraMcpConfig}" else "";
                  in
                  pkgs.runCommand "omp-mcp.json" { nativeBuildInputs = [ pkgs.python3 ]; } ''
                    python3 - "${baseMcpPath}" "${hmServersJson}" "${disabledJson}" "$out" <<'PY'
                    import json, re, sys
                    from pathlib import Path

                    base_path, hm_path, disabled_path, out_path = sys.argv[1:5]
                    base = json.loads(Path(base_path).read_text()) if base_path and Path(base_path).exists() else {}
                    hm_servers = json.loads(Path(hm_path).read_text())
                    extra_disabled = json.loads(Path(disabled_path).read_text())

                    def retarget(val):
                        if isinstance(val, str):
                            return re.sub(r"\{env:([A-Za-z_][A-Za-z0-9_]*)\}", r"''${\1}", val)
                        if isinstance(val, list):
                            return [retarget(x) for x in val]
                        if isinstance(val, dict):
                            return {k: retarget(v) for k, v in val.items()}
                        return val

                    def convert_hm(srv):
                        if srv.get("disabled", False):
                            return None
                        out = {}
                        if "url" in srv:
                            out["type"] = "http"
                            out["url"] = srv["url"]
                            if "headers" in srv:
                                out["headers"] = srv["headers"]
                        elif "command" in srv:
                            out["command"] = srv["command"]
                            if "args" in srv:
                                out["args"] = srv["args"]
                            if "env" in srv:
                                out["env"] = srv["env"]
                        return retarget(out) if out else None

                    servers = dict(base.get("mcpServers") or {})
                    for name, srv in hm_servers.items():
                        conv = convert_hm(srv)
                        if conv:
                            servers[name] = conv

                    disabled = sorted(set(base.get("disabledServers") or []) | set(extra_disabled))
                    payload = {"mcpServers": servers}
                    if disabled:
                        payload["disabledServers"] = disabled
                    Path(out_path).write_text(json.dumps(payload, indent=2) + "\n")
                    PY
                  '';
              }
        );
      };
    };
}
