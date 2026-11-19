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
      # Use the raw Handlebars template from the same pin as the default package.
      ompSystemPrompt = builtins.readFile "${inputs.oh-my-pi}/packages/coding-agent/src/prompts/system/system-prompt.md";
      mkOmpModelTemplate =
        {
          id,
          name,
          mainStyle ? "",
        }:
        toString (
          pkgs.writeText "omp-${id}.md" ''
            ${ompSystemPrompt}

            <model-profile id="${id}">
            These points are specific to you, GPT-6.2 ${name}. They refine omp's instructions in this prompt, the ones above and the ones that follow this section. Where a point conflicts with one of them, the point wins. The user's rules and context files rank above the points.

            {{#if subagent}}
            - A choice that your assignment leaves open and that no file settles is not yours to make. Put it into your result as an open question, in the field `open_questions` where your result has one. Do the parts that do not depend on it and leave the rest undone. The most likely value is still a guess.
            - Your result reports every step that you could not do, and why: a file that is missing, a tool that failed, a rule that forbids the step. A result with such a step never carries the status for finished work.
            {{else}}
            - The user's rules and context files in this prompt hold for every request, however small or plain. A direct request is carried out within them and never replaces them. Before the first change that you make or delegate, go through them and find each step that they put before this kind of work: a mockup that the user must approve, an approval, a question. When one applies, do that step first and do not start the work itself until the user has answered. Waiting for that answer is then the right action: the instructions in this prompt to keep working, to act without asking and not to stop apply to work that you may do now. When none applies, start the work, and add no step that no rule asks for.
            - A decision that is the user's to make stays open until the user has made it: what gets built, how far the scope goes, what is spent or published, and every approval. Finish the parts that do not depend on it, then ask one short question in words the user knows, and wait. Never put an assumption in its place. A fact is not a decision: what a file, a tool or one of your subagents can tell you, you look up and do not ask.
            - When all that is left is to wait for a subagent or a background job that you started, {{#has tools "wait"}}call `wait`{{else}}end your turn: omp delivers the result as a new message, and you continue from there{{/has}}. Do not wait by reasoning. Reasoning does not make the result arrive, and the turn never ends.
            - Your final answer names everything that still limits the result: a part you did not finish, a file that was missing, a tool that failed, a check you could not run, a choice you made where the request left one open. This holds for the shortest answer too, and a mention in a progress message does not replace it. Where there is nothing of the kind, say nothing about it.
            - Write the final answer for a reader who saw none of your work, in the format the request sets. The result or the answer comes first, in plain words and full sentences; details follow only as far as the reader needs them. Leave out what exists only inside your work: names of subagents and jobs, internal addresses, step numbers, labels and abbreviations that you coined. Use the words the user used.
            ${lib.optionalString (mainStyle != "") "- ${mainStyle}\n"}{{/if}}
            - Before you report work as finished, hold the result against what was asked, part by part and list item by list item. Whatever no part of the result covers, do it now or name it as not done. This is a comparison by reading: it adds no runs and no new checks.
            </model-profile>
          ''
        );
      configRelative =
        if cfg.omp.storage == "xdg" then
          lib.removePrefix "${config.home.homeDirectory}/" "${config.xdg.configHome}/omp"
        else
          ".omp";
      rawPackage =
        if cfg.omp.storage == "xdg" then
          cfg.omp.package.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./_omp-project-config.patch ];
          })
        else
          cfg.omp.package;
      managedPackage = import ./_omp-launcher.nix {
        inherit lib pkgs;
        package = rawPackage;
        settings = config.programs.omp.settings;
        storage = cfg.omp.storage;
        xdg = config.xdg;
        inherit configRelative;
      };
    in
    {
      options.modules.ai = {
        models = lib.mkOption {
          type = lib.types.submodule {
            options = {
              frontier = mkModelTierOption {
                description = "Frontier model used for the most demanding planning and review tasks.";
                model = "openai-codex/gpt-6.2-astra:max";
              };
              premium = mkModelTierOption {
                description = "Premium model used for primary interactive work.";
                model = "openai-codex/gpt-6.2-sol:xhigh";
              };
              standard = mkModelTierOption {
                description = "Standard model used for general delegated work.";
                model = "openai-codex/gpt-6.2-sol:medium";
              };
              small = mkModelTierOption {
                description = "Small model used for exploration and lightweight background work.";
                model = "openai-codex/gpt-6-luna:medium";
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

                    storage = lib.mkOption {
                      type = lib.types.enum [
                        "legacy"
                        "xdg"
                      ];
                      default = "legacy";
                      description = ''
                        Preserve legacy storage, or use XDG config/data/state/cache.
                        Move existing config and data offline before opting in; see
                        docs/omp.md. Worktrees stay in ~/.omp/wt.
                      '';
                    };

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
                      # Overlay markers prevent onboarding on every launch.
                      setupVersion = lib.mkDefault 3;
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

                      modelRoles = lib.mapAttrs (_: model: lib.mkDefault model) {
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

                      systemPromptTemplates = {
                        "openai-codex/gpt-6.2-sol" = lib.mkDefault (mkOmpModelTemplate {
                          id = "gpt-6.2-sol";
                          name = "Sol";
                        });
                        "openai-codex/gpt-6.2-astra" = lib.mkDefault (mkOmpModelTemplate {
                          id = "gpt-6.2-astra";
                          name = "Astra";
                          mainStyle = "You write tersely by default, and that is short enough: do not compress your answers further. Give one idea per sentence and drop no words. Explain a cause in simpler terms than the code, never in more complex ones.";
                        });
                      };

                      # Per-subkey defaults so a downstream `task.isolation.*`
                      # choice merges instead of replacing this block.
                      task.isolation.enabled = lib.mkDefault true;
                      isolation.backend = lib.mkDefault "auto";
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
        assertions = [
          {
            assertion =
              cfg.omp.storage != "xdg"
              || (
                lib.hasPrefix "${config.home.homeDirectory}/" config.xdg.configHome
                && !(lib.elem ".." (lib.splitString "/" configRelative))
                && !(lib.hasPrefix ".omp/" configRelative)
                && configRelative != ".omp"
              );
            message = "OMP XDG configHome must be strictly inside home and outside ~/.omp.";
          }
        ];
        modules.ai.skills.select = skills.defaultSelect;
        modules.ai.skillsSource = skills.build cfg.skills;

        home.packages = [
          pkgs.llm-agents.claude-code
        ];

        programs.mcp = cfg.mcp;
        programs.omp = lib.mkMerge [
          (builtins.removeAttrs cfg.omp [
            "extraMcpConfig"
            "disabledMcpServers"
            "lspServers"
            "storage"
            "package"
          ])
          (lib.mkIf config.programs.omp.enable {
            package = managedPackage;
            # OMP scans these alongside native user/project skills. Do not own
            # ~/.omp/agent/skills: it also contains users' locally authored skills.
            settings.skills.customDirectories = lib.mkAfter [ (toString cfg.skillsSource) ];
          })
        ];
        # Suppress upstream's config copy: OMP owns the writable main config,
        # and the managed package supplies declarations through an overlay.
        home.activation.ompConfig =
          lib.mkIf (config.programs.omp.enable && config.programs.omp.settings != null)
            {
              before = [ ];
              after = [ "writeBoundary" ];
              data = lib.mkForce "";
            };
        home.file = lib.mkIf cfg.omp.enable (
          {
            "${configRelative}/agent/themes/oxocarbon-dark.json".source =
              ./files/agents/omp/themes/oxocarbon-dark.json;
            "${configRelative}/agent/lsp.json".source =
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
                "${configRelative}/agent/mcp.json".source =
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
