# Zed / Neovim parity

The shared Zed module (`modules/home/editors/zed/default.nix`) mirrors frequently
used bindings from the Nix-rendered LazyVim configuration. Space is the leader.
This is native Zed configuration, not an attempt to run Neovim plugins inside Zed.

## Inspection baseline

The September 2026 inspection used the rendered `~/.config/nvim/init.lua`,
`lua/config/options.lua`, and `lua/plugins/*.lua`, plus the actual Nix-managed
LazyVim and plugin sources named by `dev.path` in `init.lua`. The keymaps are not
all declared in this repository: most are inherited from LazyVim's plugin specs.
The rendered configuration selects Snacks explorer/picker, Bufferline, Gitsigns,
Trouble, Outline, mini.surround, Flash, and Avante (OMP over ACP), among others.
The GitUI extra is imported, but its Mason-owned setup is disabled; `Space g g`
still belongs to Lazygit. `lazy-lock.json` alone is not an active-plugin inventory.

Zed action names, parameters, and contexts were checked against the
[1.17.2 release sources](https://github.com/zed-industries/zed/tree/v1.17.2),
including `assets/keymaps/vim.json`, the platform keymaps, and the panel/action
implementations. Recheck action availability before using this module with an
older Zed package override.

## Bindings

These leader bindings apply in full editors in Vim normal mode, not in text
fields or insert mode. `S` below means Shift-s, and similarly for other uppercase
letters. Native Zed shortcuts remain available unless explicitly replaced.

| Keys | Zed behavior | Neovim source / qualification |
| --- | --- | --- |
| `Space e`, `Space f e` | Open/focus project tree; press again in tree to close | Snacks explorer |
| `Space Space`, `Space f f` | Find files | Snacks file picker |
| `Space ,`, `Space f b` | Switch tabs across panes | Approximation of Snacks buffer picker |
| `Space f p` | Recent projects | Snacks projects |
| `Space f n` | New file | LazyVim |
| `Space /`, `Space s g` | Project search | Snacks grep |
| `Space s b` | Search current buffer | Approximation of Snacks line picker |
| `Space s r` | Project search with replace enabled (normal/visual) | Grug Far equivalent, not its editable results buffer |
| `Space s s` | Current-file symbol picker | Snacks document symbols |
| `Space s S` | Workspace symbol picker | Snacks workspace symbols |
| `Space :`, `Space s C` | Command palette | Commands/history approximation |
| `Space s k` | Open Zed keymap editor | Approximation of Snacks keymap picker |
| `Space s R` | Reopen last picker | Snacks resume |
| `H`, `L` | Previous/next tab | Bufferline; replaces native Vim screen-top/bottom motions |
| `Space b b`, Space + backtick | Alternate file | LazyVim alternate buffer |
| `Space b d` | Close current tab | Snacks buffer delete approximation |
| `Space b o` | Close other tabs in current pane | Narrower than deleting other Neovim buffers |
| `Space -`, `Space \|` | Split below/right | LazyVim windows |
| `Ctrl-h/j/k/l` | Focus adjacent pane | Normal mode only |
| `Space w d` | Close current tab | Zed closes the pane when its last item closes; not exact window deletion |
| `Space w m` | Toggle zoom | LazyVim window maximization approximation |
| `Ctrl-s` | Save | Normal/visual/insert; replaces Zed's insert-mode signature-help shortcut |
| `Alt-j/k` | Move lines down/up | Normal/visual/insert |
| `Space c f` | Format file / visual selection | Conform; external formatters do not support Zed selection formatting |
| `Space c a` | Code actions (normal/visual) | LazyVim LSP |
| `Space c l` | Task picker (`task::Spawn`) | Manual lint/validation tasks; terminal output, not a diagnostics adapter |
| `Space c r`, `Space c o` | Rename symbol / organize imports | Requires language-server support |
| `Space c s` | Focus outline panel / return to editor | Outline equivalent; also bound inside outline panel |
| `Space x x`, `Space s d` | Project diagnostics | Trouble/Snacks equivalents |
| `g r` | Find references | LazyVim's shorter binding instead of Zed's `g r r` |
| `g K`, insert `Ctrl-k` | Signature help | LazyVim LSP; insert `Ctrl-k` replaces Vim digraph entry |
| `[[`, `]]` | Previous/next symbol reference | Snacks words; replaces Zed section motions |
| `[h`, `]h` | Previous/next Git hunk | Gitsigns |
| `Space g g`, `Space g s` | Focus Git panel | Native UI, not Lazygit |
| `Space g d` | Project diff | Approximation of Snacks diff picker |
| `Space g h p` | Toggle selected inline diff hunks (normal/visual) | Gitsigns inline preview equivalent |
| `Space g h b`, `Space g h B` | Blame hover / file blame | Gitsigns equivalents |
| `Space g B`, `Space g Y` | Open/copy line permalink (normal/visual) | Snacks remote browse; requires supported Git remote |
| `Space a a`, `Space a f` | Focus agent | Avante ask/focus approximation |
| `Space a n` | New agent thread | Avante new-chat equivalent |
| Visual `Space a e` | Inline assist | Avante edit-selection equivalent; uses Zed's inline-assist configuration |
| `Space f t`, `Ctrl-/`, `Ctrl-_` | Toggle terminal panel | Reuses terminal instead of creating one each time |
| `Space t t` | New terminal | Existing Zed-only shortcut retained |
| `g s a`, `g s d`, `g s r` | Add/delete/replace surround | Native surround actions with mini.surround-style prefixes; add also works in visual mode |

Zed already supplies useful native bindings such as `gd`, `gD`, `gI`, `gy`, `K`,
`[d`/`]d`, `[b`/`]b`, `gc`, and `Ctrl-w` window commands. They are not redeclared.
Language-server operations remain capability-dependent.

### Inside the file tree

`Space e` and `Space f e` work in the project panel as well as the editor;
`q` also closes it. These invoke `project_panel::Toggle`, not just `ToggleFocus`.
If the panel is visible but not focused, the first press focuses it.

- `a`: new file; `r`: rename; `d`: trash **with confirmation**.
- `y` / `p`: copy/paste entries (not Snacks' path-register behavior).
- Backspace: select parent (does not change the workspace root).
- `Ctrl-s` / `Ctrl-v`: open horizontal/vertical split.
- `[g` / `]g`: previous/next Git-changed entry.
- Native `h/j/k/l` collapse/navigate/expand; Enter opens permanently.
- Native `Cmd-Alt-n` on macOS creates a directory. `a` does not emulate Snacks'
  combined file/directory prompt, and `l` is expand rather than open-file.

These overrides require `ProjectPanel && not_editing`, so typing a filename
cannot invoke delete, rename, or a leader shortcut. In pickers, `Ctrl-j/k`
navigate results; native `Ctrl-n/p` also work. Terminal toggling has a separate
terminal context; Space sequences are never intercepted from the shell.

## Settings and remaining differences

- Formatting stays manual. Oxocarbon, Nerd Fonts, relative line numbers, and
  the existing Nix formatter/LSP configuration are retained.
- `vim.use_system_clipboard = "never"` matches Neovim's empty `clipboard` option.
  Ordinary Vim yanks/deletes use internal registers; use explicit `"+y` / `"+p`
  for the system clipboard. Native platform copy/paste remains available.
- Root/cwd variants (`Space E`, `fE`, `fF`, `sG`, `fT`) are not mapped to identical
  actions: Zed worktrees and terminal working directories are a different model.
- Surround actions use Zed's vim-surround semantics. For example, `gsaiw)` adds
  parentheses to a word; mini.surround's search ranges, find/highlight operations,
  and all delimiter semantics are not reproduced. Native `ys`/`ds`/`cs` remain.
- Flash jumps, Trouble-specific lists, Gitsigns stage/reset/undo-stage behavior,
  Diffview merge conflict choices, Octo/GH review flows, database UI, and Avante
  apply/accept workflows are not reproduced by this keymap.
- The agent panel is not Avante, and merely focusing it does not promise that a
  visual selection has been attached as context. Existing agent providers and
  model choices are not changed.
- Language tooling is now supplied through Zed's Nix `extraPackages` and explicit
  server/formatter paths, including for GUI launches; agent dependencies are unchanged.
- Spellchecking parity and automatic Markdown TOC generation are not provided.

## Language tooling

New extension IDs are `lua`, `marksman`, `tombi`, `fsharp`, and `html`; existing
`toml`, `csharp`, `kotlin`, and other extensions remain. Tombi is the supported
TOML language-server/formatter alternative to Taplo, not a Taplo compatibility
shim. Native Zed-extension Roslyn (C#) and Kotlin integration is kept rather
than replaced with Neovim-specific servers.

| Language | Tooling / behavior |
| --- | --- |
| Nix | Existing nixd and Alejandra; Statix is a manual task. |
| Lua | LuaLS plus StyLua (`--respect-ignores`, buffer path); LuaLS formatting disabled. |
| Python | `ty` for type analysis, Ruff server for lint/format; formatting also runs `source.organizeImports.ruff`. |
| Go | gopls with `gofumpt` and `staticcheck` enabled; server formatting also runs `source.organizeImports`; hard tabs. Go and golangci-lint supplied. |
| Rust | rust-analyzer, rustc, Cargo, rustfmt, and Clippy supplied. |
| F# | .NET SDK and FsAutoComplete (adaptive server); language-server formatting. |
| Markdown | Marksman, Prettier with buffer path, editor-width wrapping; markdownlint-cli2 task. |
| TOML | Tombi LSP and formatter. |
| Shell | bash-language-server with explicit ShellCheck/shfmt paths: native ShellCheck diagnostics; shfmt formatter. |
| SQL | SQLFluff formatter and manual lint task; choose dialect/templater in project `.sqlfluff`, no global ANSI assumption. |
| Terraform | terraform-ls and server formatting; Terraform/TFLint manual checks. |
| YAML / Helm | Nix YAML language server and helm-ls; schema policy below. |
| Dockerfile | Existing extension; Hadolint manual task. |

Keep LuaLS Neovim globals (such as `vim`) project-local, e.g. in `.luarc.json`;
the shared module does not mark them valid in every Lua project. Formatting
remains explicit (`format_on_save = "off"`); import actions above run on format,
not automatically on save. CLI-only linters report in task terminals: there is
no fake diagnostics integration. Native language-server diagnostics remain available.

## Manual tasks

`Space c l` opens the task picker in normal mode. All 12 tasks use `save = "none"`:
**save files yourself first**; checks read disk, not unsaved buffers. Tasks reveal
the terminal, leave output visible, and disallow concurrent runs of the same task.
Commands below abbreviate Nix-built, ShellCheck-checked wrappers. Zed treats task
arguments as shell fragments, so wrappers read quoted file paths from environment
variables instead of interpolating filenames into those fragments. Markdown's
literal-path prefix also prevents filenames from being interpreted as glob patterns.
Default cwd is `$ZED_WORKTREE_ROOT`; “current directory” means
`$ZED_DIRNAME`, not an automatically discovered module/chart root.

| Task label | Command / scope |
| --- | --- |
| Lint: Hadolint (saved Dockerfile) | `hadolint "$ZED_FILE"` |
| Lint: Markdown (saved file) | `markdownlint-cli2 --no-globs ":$ZED_FILE"` |
| Lint: SQLFluff (saved file, project dialect) | `sqlfluff lint "$ZED_FILE"` |
| Lint: Go (saved worktree/module) | `golangci-lint run` at worktree root |
| Lint: Statix (saved worktree) | `statix check .` at worktree root |
| Lint: ShellCheck (saved file) | `shellcheck "$ZED_FILE"` (in addition to native diagnostics) |
| Terraform: validate (saved current module) | `terraform validate -no-color` in current directory |
| Terraform: TFLint (saved current module) | `tflint` in current directory |
| Kubernetes: validate saved manifest (kubeconform) | `kubeconform -strict -summary "$ZED_FILE"` |
| Helm: lint chart (open Chart.yaml first) | Guarded `helm lint --strict .` in current directory |
| Helm: render chart (open Chart.yaml first) | Guarded `helm template zed-preview . --include-crds` in current directory |
| Kustomize: build (open kustomization.yaml first) | Guarded `kustomize build .` in current directory |

Terraform checks require any necessary initialization/plugins to be prepared
separately; tasks do not run init, apply, or dependency updates. Both Helm tasks
require `Chart.yaml` in the current directory and set `KUBECONFIG=/dev/null`;
they lint/render locally with `--kube-version 1.36.0` for Helm capabilities, with
no apply, dependency updates, or cluster access. Remote chart schema references
may still use the network.
Kustomize requires `kustomization.yaml`, `kustomization.yml`, or `Kustomization`;
remote bases may use the network. Rendered Helm/Kustomize output may contain
secrets: treat terminal output accordingly.

`modules/home/dev/kubernetes.nix` already supplies Kubernetes CLI tools and is
untouched. Tasks use absolute kubeconform/Kustomize/plain Helm commands; plain
Helm is deliberately **not** added to Zed's wrapper PATH, preserving the existing
plugin-wrapped `helm` in the terminal (diff, secrets, unittest).

## YAML, Kubernetes, and Helm schemas

YAML validation, hover, completion, and formatting are enabled, with `!reference`
sequence and `!unsafe` scalar tags. Generic YAML still uses SchemaStore
(`schemaStore.enable = true`) and may download unrelated schemas; this is not a
fully offline setup. `kubernetesCRDStore.enable = false` disables CRD autodiscovery
because public schema URLs can disclose private API groups/kinds.

`modules/home/editors/zed/kubernetes.nix` builds one local schema bundle for YAML
LS, Helm's embedded YAML server, and kubeconform. It replaces the YAML server's
`kubernetes` alias and kubeconform's remote defaults with pinned **Kubernetes
1.36.0** definitions plus **114 public CRD GVK schemas**: **426 GVKs total**, including
312 Kubernetes built-in/List GVKs before downstream additions. Datree's
CRDs-catalog is the shared **`crds-catalog` non-flake input**, pinned by revision and
NAR hash in `flake.lock`. `schemas/pins.json` holds the curated GVK/path selection
and the separately commit/SHA256-pinned Kubernetes definitions. Validation uses
the local output rather than constructing public URLs from resource kinds.

Update only the catalog with `nix flake update crds-catalog`, then rebuild the
schema package and validate representative manifests. The input fetches the whole
source snapshot (about **207 MiB unpacked** at the initial pin, versus **15 MiB**
for the 114 selected schemas), not Git history. Only selected schemas enter the
bundle; new catalog entries are not automatically enabled, and missing selected
paths fail the build. `inventory.json` records the resolved input revision (or
NAR hash/store path for a local input) and catalog-relative source paths.
Downstream flakes can override this input through the shared flake-file contract;
see the [downstream example](./downstream-template.md#zed-kubernetes-and-crd-schemas).

The catalog covers Prometheus Operator, Strimzi, CloudNativePG (CNPG), External
Secrets Operator (ESO) and generators, cert-manager/ACME, Gateway API, Envoy Gateway,
ExternalDNS, and Argo CD's `Application`, `ApplicationSet`, and `AppProject`—**not all
Argo**. These are not exact installed operator releases; downstream CRD definitions
can override matching public group/version/kind (GVK) schemas.

The read-only Home Manager option `aw1cks.zed.kubernetes.schemaPackage` exposes
`bundle.json`, `inventory.json` (GVKs and provenance), and the `kubeconform/` tree.
The `schemaURI` settings key is a `file://` Nix store path to `bundle.json`, with
string context stripped because Nix attribute names cannot carry it.
`xdg.configFile."zed/kubernetes-schemas".source` retains the package dependency in
the Home Manager closure and exposes the same output under Zed's config directory.

`aw1cks.zed.kubernetes.manifestGlobs` associates the bundle with manifest-only YAML.
Its regular default configuration list contains `**/k8s/manifests/**/*.yaml` /
`*.yml` and `**/kubernetes/manifests/**/*.yaml` / `*.yml`, not all YAML, CI, or values.
Downstream list assignments append; `lib.mkForce` can deliberately replace the
list. No raw Zed settings replacement is needed; see the
[downstream Home Manager example](./downstream-template.md#zed-kubernetes-and-crd-schemas).

Helm file associations remain limited to `**/charts/*/templates/**/*.{yaml,yml,tpl}`
and `**/charts/*/values*.{yaml,yml}` (separate globs in Nix). Adapt language file
associations in project `.zed/settings.json` for other chart layouts. Helm's YAML
server associates the same local bundle with `templates/**`; automatic Helm lint
is disabled. Both extension settings shapes are supplied: Helm 0.0.6 uses
`lsp.helm_ls.settings."helm-ls"`, while 0.0.8 uses `lsp.helm.settings`.

`aw1cks.zed.kubernetes.extraCRDs` is an additive list of local paths to raw
`apiextensions.k8s.io/v1` CRD YAML/JSON definitions, including multi-document files
and `List` wrappers. Only served versions are compiled. Extras override built-in
schemas by matching GVK; duplicate GVKs among extras fail the build rather than
silently choosing one. References must be self-contained fragment references;
nonlocal references, including remote URLs, are rejected.

Private definitions enter the **world-readable Nix store** and potentially binary
caches. Supply definitions only, never resource instances or credentials. Strict
unknown-field checks catch typos while honoring `x-kubernetes-preserve-unknown-fields`.
The builder narrowly converts supported inline RE2 case folding; unsupported
forms fail rather than silently dropping constraints. Structural schema checks
do not validate CEL, admission, defaulting, or conversion behavior.

The kubeconform task uses `-kubernetes-version 1.36.0`, `-strict`, and only the local
`kubeconform/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json` schema tree.
Unknown GVKs have **no remote fallback**; missing-schema failures stay visible,
without `-ignore-missing-schemas`. Neither editor nor task detects the cluster
version. Helm rendering and remote-base fetching retain the network caveats above.

## Applying and validation

The source of truth is the Nix module. `just rebuild` applies settings, tasks,
extension requests, and the expanded GUI wrapper PATH through Home Manager.
Editing only `~/.config/zed/*.json` is not a durable change. Restart Zed after
adding extension requests: version 1.17.2 checks `auto_install_extensions` at
startup, not on every settings-file change. Installation requires network access.

The language/task configuration was evaluated for `mbp` and built as a narrow
rendered artifact, including all task wrappers. Fixture tests covered valid/invalid
inputs, chart/overlay guards, literal filenames with shell/glob metacharacters,
and public Kubernetes schema validation. The new LSPs were smoke-tested in
synthetic workspaces, and external formatters were checked for idempotence.
A synthetic downstream consumer using the reusable export validated additive
CRD/glob and GVK override semantics. The public/additive/override fixture matrix
passed 62 YAML LS and 62 kubeconform checks, with no schema lookup errors or skipped
resources and with runtime network access denied. Thirteen offline builder tests
cover normalization, references, strictness, Lists, collisions, and overrides.

The catalog-input migration retained the same upstream revision: the bundle and
all 426 kubeconform files matched their pre-migration SHA256 hashes; only inventory
provenance changed. A generated downstream consumer also passed 68 YAML LS and
68 kubeconform checks with a top-level local catalog override, including catalog
schema replacement, `extraCRDs` precedence, and revision-less input provenance.
Nix formatting, Ruff, and focused editor diagnostics passed. The migration's broad
`nix flake check --offline --no-build` attempt timed out after 120 seconds while
checking `nixosConfigurations.desktop`; it is not counted as a pass.

These checks are not a system switch, real-project restore/build, private
consumer validation, or interactive Zed test. Tombi 0.10.4 formatting worked in
the smoke test, but its process needed stdin closed after LSP shutdown/exit;
that upstream lifecycle quirk is not a configuration workaround here.
Project dependency restores, actual schema targets/CRDs, and cluster authorization
remain separate concerns. No validation task accesses a cluster automatically.
