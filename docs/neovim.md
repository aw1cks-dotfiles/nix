# Neovim: upstream module, local policy

The shared [Neovim module](../modules/home/editors/neovim/default.nix) imports
`inputs.lazyvim-nix.homeManagerModules.default`. Keep the maintained upstream
module authoritative; do not restore the former local module fork. The local
cutover uses the locked upstream input and supported `lib.lazyConfig` API, not
patched upstream sources. This is a local integration; it does not file new
upstream issues or PRs.

Downstream consumers must update their `lazyvim-nix` lock alongside
`dendritic-lib` when adopting this cutover: shared `follows` wiring can still
resolve to a separately locked upstream input. Updating this repository's root
pin alone does not establish adoption in a private downstream configuration.

Commit that downstream lock update with the library adoption; a working-tree-only
pin bump is insufficient. This cutover is validated against `30f8896`; the old
`2189337` manifest produces diff/Kotlin parser-query mismatches. Use
`nix flake check --no-write-lock-file` during review so validation cannot silently
refresh unrelated inputs.

## Shared language-server packages

`modules/home/dev/_language-servers.nix` owns the server package selection used by
both this module's `programs.lazyvim.extraPackages` and the independent
`aw1cks.modules.home.language-servers` atom. The developer profile imports that
atom to expose servers through `home.packages`, including on editorless hosts.
Neovim keeps its wrapper PATH so standalone and GUI-launched editors retain the
same executables. Importing Neovim alone does not install the servers globally.

Only the shared Rust analyzer has higher package priority, to beat rustup's
per-toolchain `rust-analyzer` proxy when both enter the user environment. It
comes from the Nix stable toolchain (see [Rust toolchains](./architecture.md#rust-toolchains)).
Rustup owns the compiler and Cargo proxies, which also replace nixpkgs `cargo`
and `rustc` in the wrapper PATH when the rust module is imported; without it the
wrapper falls back to the Nix stable toolchain. LazyVim's automatic Rust
dependencies still add nixpkgs `rust-analyzer` behind the shared one. Other
editor runtimes, formatters, debuggers, and upstream automatic extra
dependencies remain unchanged; repeated references to the same store output are
not separate installations. The server atom alone does not provision every
project's toolchain or dependencies.
The Neovim wrapper defaults `RUSTUP_HOME` to the Rust module's configured
location, including relocated homes, while preserving an explicit launch-time
override. GUI launches therefore do not depend on inherited shell variables.

OMP uses its native definitions and supported project-local bin directories
before PATH; missing executables are skipped rather than installed. Startup root
markers are checked in the current working directory, not ancestors.

Providing executables alone does not register an OMP server, so
`aw1cks.modules.home.ai` writes `~/.omp/agent/lsp.json` from
`modules/home/dev/files/agents/omp/_lsp.nix`. That file restates the entries the
pinned definitions cannot use as shipped: nixpkgs ships `OmniSharp` where OMP
expects `omnisharp`; OMP's `kotlin-lsp` entry targets the newer JetBrains server
and passes `--stdio`, which makes our `kotlin-language-server` exit; and the F#
and TOML servers are absent from the built-in set.

Docker Compose uses `yamlls` for both YAML syntax and compose-schema diagnostics.
Its root markers include the four Compose basenames as well as `.git`, so
standalone Compose directories work without a Git repository. There is no
dedicated OMP Compose server; the package stays installed because Neovim
configures `docker_compose_language_service` itself.

OMP merges each server as `{ ...builtin, ...override }`, so overrides are shallow
and arrays replace wholesale. Set `modules.ai.omp.lspServers.<name>` to change one
server, or `disabled = true` to suppress it. The generated file preserves that
marker so OMP suppresses built-in servers as well as added servers, rather than
falling back to a built-in definition when an override is omitted.

Coverage is still per-project: `fsautocomplete` needs a restored project. Its
`initOptions.AutomaticWorkspaceInit = true` lets it load projects without
F#-specific workspace-selection requests from OMP.

Root markers are matched in the working directory only, never in ancestors and
never against the queried file's own directory. Start OMP in the repository or
crate root; a monorepo whose marker sits in `python/` or `rust/<crate>/` is
invisible from the repository root no matter what the file path is.

`lsp.requestTimeout` is raised to 60s. The lsp tool's per-call deadline is
`max(20, requestTimeout)`, and the pinned `tsc` is 5.9.3, which rejects `--lsp`,
so OMP drops its `typescript-native` definition and `typescript-language-server`
is installed instead.

`sqls` is not in the shared defaults even though the package is installed. It
advertises no `diagnosticProvider`, and without a configured database it never
pushes diagnostics, so OMP's `diagnostics` action waits indefinitely instead of
returning an empty result. Opt in per consumer with `lspServers.sqls` where that
trade is acceptable.

## clangd

C and C++ are served by `clangd` from `clang-tools`, which is the only nixpkgs
source of the binary; its closure is roughly 2.1 GB because it pulls clang and
llvm. Both clients use it: `neovim/files/plugins/clangd.lua` sets the server for
Neovim, and the OMP entry only widens `rootMarkers` with `.git`.

The language-server atom installs the policy at clangd's native user path:
`~/Library/Preferences/clangd/config.yaml` on Darwin and
`$XDG_CONFIG_HOME/clangd/config.yaml` (normally `~/.config/clangd/config.yaml`) on
Linux. Darwin does not use the XDG copy. User config has higher precedence than
the nearest project `.clangd`, then ancestors; projects cannot undo the shared
removals. The policy strips selected GCC-only flags and `-Werror=*`, adds
`-Wall`, and enables unused-include diagnostics.

Language standards and header languages stay project-owned through compilation
databases or `.clangd`. The user policy never adds `-std`: doing so overrides a
project's C++23 command, while treating every `.h` as C breaks C++ headers.
Neovim uses portable clangd flags; `--malloc-trim` is not supported by the pinned
Darwin binary.

No client passes `--compile-commands-dir`. clangd searches parent directories and
`build/` itself, and pinning the flag would defeat a project's own
`CompilationDatabase:` redirect. Root markers name `build` as a bare directory,
because a nested path such as `build/compile_commands.json` resolves the root to
`build/` rather than the project.

Without a compilation database clangd falls back to a generic command line, so
diagnostics still appear but include paths are missing. On this workstation none
of the C/C++ repositories ship `compile_commands.json`, `compile_flags.txt`, or
`.clangd`, so expect include-resolution errors until a project generates a
database.

Write-time LSP hooks do not start a server. `lsp.formatOnWrite` and
`lsp.diagnosticsOnWrite` only act on an already-running client, so the first write
to a file in a fresh project gets neither formatting nor diagnostics; the same
write succeeds once any LSP request or edit has warmed the client. Treat the first
edit after opening a repository as unchecked.

OMP also loads `lsp.json` from the working directory and from `~/.omp/agent`
without a trust prompt, and spawns whatever those files name. A cloned repository
can therefore execute commands as you. Keep those files out of untrusted
checkouts, and review `lsp.json` in a repository before running OMP inside it.
Home Manager owns `~/.omp/agent/lsp.json` on hosts with this module enabled, so
add servers through the module rather than editing that file.

This shares binaries, not running server processes or Neovim's server settings.
Terminal OMP needs the HM profile on PATH; Avante ACP inherits Neovim's wrapper
environment. Other GUI launchers, services, and ACP clients need their own
environment setup. Zed remains independently configured. Package provisioning
is not a blanket offline guarantee.

## Why seven supplemental package specs remain

`programs.lazyvim.configFiles = ./files` installs our source-tree configuration,
but upstream's **plugin discovery** still scans the installed
`$HOME/.config/<appName>`, not that source tree. A fresh or sandboxed evaluation
cannot rely on those installed files. Separately,
[upstream #109](https://github.com/pfassina/lazyvim-nix/issues/109) tracks implicit
LazyVim default extras and dependency-only plugins missing from generated data.

The `plugins.nix-managed` fragment supplies only this profile's gaps:

| Plugin | Nix package |
| --- | --- |
| `yetone/avante.nvim` | `pkgs.vimPlugins.avante-nvim` |
| `nyoom-engineering/oxocarbon.nvim` | `pkgs.vimPlugins.oxocarbon-nvim` |
| `dlyongemallo/diffview-plus.nvim` | Local `diffviewPackage` (`v0.39`) |
| `stevearc/dressing.nvim` | `pkgs.vimPlugins.dressing-nvim` |
| `HakonHarnes/img-clip.nvim` | `pkgs.vimPlugins.img-clip-nvim` |
| `saghen/blink.cmp` | `pkgs.vimPlugins.blink-cmp` |
| `rafamadriz/friendly-snippets` | `pkgs.vimPlugins.friendly-snippets` |

Each generated spec uses an explicit store `dir`, `dev = false`, `pin = true`,
and `optional = true`. These are package-location supplements, not independent
plugin enablement: removing a plugin from the Lua profile must not resurrect it.
Dependency-only Dressing, img-clip and friendly-snippets also use `lazy = true`;
provisioning them must not make them eager. Preserve nixpkgs' native Avante
artifacts and Blink Rust matcher rather than replacing their packages with raw
plugin sources or maintaining a custom native build.

Diffview uses the maintained [diffview-plus fork](https://github.com/dlyongemallo/diffview-plus.nvim).
The module pins release `v0.39` with `buildVimPlugin` because the locked nixpkgs
does not yet provide `vimPlugins.diffview-plus-nvim`. The Lua spec explicitly sets
`main = "diffview"`: the fork keeps that module namespace and the `Diffview*`
commands, including the existing `diff3_mixed` merge layout. The original plugin is
explicitly disabled because upstream discovery can still emit it from the
pre-switch installed configuration; loading both mixes their shared Lua modules.
The package check bootstraps the plugin before requiring its internal runtime
modules, which depend on `DiffviewGlobal`.

## Treesitter and runtime files

Keep `pluginSource = "latest"` for the **whole** upstream-selected Treesitter
stack: plugin, grammar manifest/parser builds, and query files. Do not combine
latest parsers with nixpkgs queries, or fix a mismatch by overriding only one
component. `treesitterParsers` supplies additional language selections to that
upstream mechanism.

Upstream links parser/query data and automatically installs runtime directories
from `configFiles` (including our `ftplugin/`); no local manual linking is needed.
It also intercepts LazyVim's runtime parser installer at `LazyDone`: missing
parsers produce Nix configuration guidance instead of compiling into a read-only
store-backed directory. Add parsers through `treesitterParsers` or enabled extras.

The independent local [`_treesitter-query-check.lua`](../modules/home/editors/neovim/_treesitter-query-check.lua)
is wired through `home.checks` only when the build platform can execute the host
platform. It runs the configured Neovim against the generated parser/query site,
loads installed parsers, and parses their shipped queries, including inherited
query resolution. This intentionally makes a broken managed parser/query pair a
local check failure. It is **not** validation of arbitrary user queries or every
other plugin's runtime queries, nor an upstream module requirement.

## Upstream decisions to retain

- [#115](https://github.com/pfassina/lazyvim-nix/pull/115) landed full plugin
  identities/collision-safe dev paths and store-backed lazy.nvim bootstrap,
  superseding [#110](https://github.com/pfassina/lazyvim-nix/pull/110) and
  [#111](https://github.com/pfassina/lazyvim-nix/pull/111).
- [#108](https://github.com/pfassina/lazyvim-nix/pull/108) landed parser-manifest
  regeneration and update/CI coherence; use it instead of closed
  [#113](https://github.com/pfassina/lazyvim-nix/pull/113). The maintainer rejected
  the latter's evaluation-time guard: upstream data drift belongs in upstream CI,
  not an error users cannot repair during evaluation.
- [#112](https://github.com/pfassina/lazyvim-nix/pull/112)'s upstream build-time
  checker was declined for cross-compilation, per-build Neovim cost, and turning
  one broken filetype into a failed switch. Our native `home.checks` policy is
  deliberately separate, not a reason to reopen that rejected requirement.
- [#114](https://github.com/pfassina/lazyvim-nix/pull/114) was declined in favor of
  the existing generator work tracked by #109: record real default extras and
  dependency-only specs with pinned versions in generated data. Do not reintroduce
  import-from-derivation, evaluation-time user-config execution, or a custom Blink
  Rust build.

Future upstream work should prioritize narrow `configFiles` source discovery and
that existing #109 generator path, not re-litigate the rejected guards.

## Local policy and validation expectations

`000-lazy-bootstrap.lua` also carries a narrow runtime ownership lookup patch.
The #115 `owner--repo` dev paths (and direct Nix package paths) do not match
`plugin.name`; lazy.nvim's basename lookup can therefore miss require-triggered
runtimepath registration and configuration, including Trouble loaded by lualine.
During spec discovery, before plugin `init`, the patch overrides the **loaded**
`lazy.core.plugin.find` to match the directory before `/lua/` against configured
`plugin.dir` values, using the normal or fast spec table as appropriate. This is
not a module fork or package/version override. Remove it when upstream lookup
supports configured directories, after exercising require-triggered loading and
the Trouble/lualine statusline path under a fresh HOME.

`checks.<system>.neovim-plugin-loading` exercises real require-triggered Trouble
activation and symbol-source discovery with both `owner--repo` links and direct
package directories, including lazy.nvim's fast ownership lookup:

```sh
nix build .#checks.aarch64-darwin.neovim-plugin-loading --no-link
```

The `000-lazy-bootstrap.lua` rocks-disable `init` callback is late: it is **not** a
setup-time rocks fix or an offline guarantee. Nix-managed plugin locations alone
do not prove that startup or application integrations cannot access the network.
[Avante/OMP](./avante-omp.md) is a separate application integration, not module
bootstrap or packaging policy.

The local `<leader>ul` binding reuses Snacks' cached `line_number` toggle, replacing
the removed LazyVim `Util.toggle_number` API. An off/on cycle preserves the prior
absolute/relative number modes and retains the existing Gitsigns sign toggle.

For updates, evaluate the real host profile and build its native home checks.
Use a fresh HOME/XDG runtime smoke to inspect plugin store paths, absence of
unexpected clones/phantom identities, lazy completion and dependency loading,
Blink's Rust matcher, and diff/Kotlin/Lua queries. Exercise ordinary startup and
Avante/OMP separately; parser validation does not prove plugin initialization or
ACP behavior. These are validation expectations, not a claim that all surfaces
have passed for the current checkout.

## Git mergetool

`git mt` aliases `git mergetool` and launches Diffview with Git's `$MERGED`
working-tree path. Do not use `$MERGE`: Git does not set that variable, and the
empty filename opens the current directory, allowing the directory explorer to take
focus from the merge view during startup.

## File explorer

`programs.lazyvim.extras.editor."neo-tree".enable` explicitly selects Neo-tree,
matching the explorer in the archived
[`aw1cks-dotfiles/nvim` lockfile](https://github.com/aw1cks-dotfiles/nvim/blob/main/lazy-lock.json).
Without that selection, a fresh LazyVim installation defaults to Snacks Explorer,
which has a different layout and mappings. Keep the supported extra authoritative;
no local imitation of Neo-tree's bindings or separate icon package is needed.

`<leader>e` / `<leader>fe` toggle the project-root explorer; `<leader>E` /
`<leader>fE` use the current directory. Inside the tree, `l` opens, `h` closes a
node, `a` adds, `d` deletes, `r` renames, and `H` toggles hidden files. File and
folder glyphs use the existing MiniIcons integration and require a Nerd Font in
the terminal or GUI.

## Ansible and project-local configuration

The supported Ansible extra supplies `nvim-ansible` filetype detection and
`ansiblels`. Nix installs Ansible Core, `ansible-lint`, and the language server as
Home Manager PATH fallbacks, not fixed per-workspace executable paths. The native
server uses offline linting, disables automatic lint fixes, and does not enable
execution-environment containers or paid completion services.

For a root with an ancestor `.envrc`, the server starts through
`direnv exec <root> ansible-language-server --stdio`. This loads project tool and
collection paths after Neovim's wrapper. Each tool retains its own interpreter;
the server does not emulate a virtualenv using a hardcoded Python path.
Without `.envrc`, it uses the ordinary PATH fallbacks. A blocked or broken
environment is not silently replaced with global tools; review it and run
`direnv allow .` before starting the client. Restart the client after environment
changes. This does not install Galaxy requirements or manage containers.

Keep tool versions in a project devShell and `.envrc` (`use flake`), inventory and
search paths in `ansible.cfg`, collection/role pins in `requirements.yml`, and lint
policy in `.ansible-lint`. Include the full toolchain in the devShell when pinning
project versions. Resolve project requirements explicitly; opening a buffer must
not install them.

`exrc` enables Neovim's native trusted `.nvim.lua` mechanism. Review a local file
and use `:trust` before allowing it to execute. Scope overrides to that repo;
do not classify every YAML file or mutate LSP defaults for unrelated workspaces.
For example, a project's `.nvim.lua` can activate an unconventional playbook name:

```lua
local root = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
vim.filetype.add({
  filename = {
    [root .. "/site.yml"] = "yaml.ansible",
  },
})
```

The supplied detector recognizes conventional playbook and role paths but is
still filename/path based. `site.yml` is ordinary YAML without an explicit
association; CI and unrelated YAML keep their ordinary schema support.
Jinja expressions in playbooks support variables; standalone `.j2` templates and
Jinja blocks are not covered by this baseline.

## YAML and Kubernetes schemas

Neovim and Zed import the shared `aw1cks.modules.home.yaml-schemas` module from
`modules/home/editors/yaml-schemas.nix`. SchemaStore retains broad YAML coverage,
including GitLab CI, GitHub Actions, and Compose. The strict Kubernetes bundle is
associated with configured manifest globs. Neovim additionally uses `detected.json`
as a fallback for other YAML filenames: resource-specific fields become available
once a document has a recognized `apiVersion` and `kind`, even outside a Git repo.
Unrelated, partial, and unknown documents receive no Kubernetes constraints.
`aw1cks.yaml.kubernetes.extraCRDs` and `manifestGlobs`, plus
`aw1cks.yaml.extraSchemas`, accept additive downstream declarations. See the
[Home Manager examples](./downstream-template.md#shared-yaml-kubernetes-and-crd-schemas)
and [schema policy](./zed-parity.md#yaml-kubernetes-and-helm-schemas).

Neovim supplies the packaged SchemaStore.nvim catalog through YAML LS's
`json/schemaAssociations` notification, below explicit schema settings in
precedence. Its built-in remote catalog fetch stays disabled to avoid duplication.
The detection fallback excludes SchemaStore filename patterns, so it does not
combine Kubernetes constraints with catalog schemas. Zed retains its native
SchemaStore integration and path-scoped Kubernetes associations. In both editors,
explicit custom schemas override catalog associations and the Neovim fallback.

The bundle dispatches each YAML document by exact `apiVersion` and `kind`, including
known List items. Unknown GVKs deliberately receive no resource-specific editor
validation rather than an unrelated closest-match schema. This is incomplete
coverage, not proof of validity: strict kubeconform validation separately reports
a missing schema, with no remote fallback.

This supersedes the Kubernetes investigation, not the rationale for removing
`k8s-whisper`: it selected incorrect schemas and produced kubeconfig prompts.
Do not reinstate it. The shared integration does not inspect kubeconfig, contact
a cluster, or guess remote CRD URLs. SchemaStore and explicit remote schema URLs
can still fetch at runtime. Real private downstream validation is not yet claimed.

## Helm

The supported Helm extra detects charts by `Chart.yaml`, including standalone
charts outside a `charts/` directory. Templates and `_helpers.tpl` use `helm`;
`values.yaml` and `values-*.yaml` use `yaml.helm-values`. Only `helm_ls` owns the
values buffers: attaching ordinary `yamlls` as well contributes unrelated
Kubernetes completion items. `Chart.yaml`, the JSON schema, and unrelated YAML
retain their ordinary language servers.

`modules/home/editors/_helm-yamlls.nix` supplies the embedded YAML-server settings
for both Neovim and Zed: an absolute executable, the pinned Kubernetes/CRD bundle
for templates, explicit custom schemas, SchemaStore, and disabled CRD discovery.
This replaces Helm LS's default remote `kubernetes` alias. Neovim retains Helm
LS's default lint diagnostics; Zed keeps its existing explicit lint/render tasks.

**Known upstream limitation:** Helm LS 0.5.4 fails to generate values schemas
when a valid `values.schema.json` contains Boolean schema fields such as
`"additionalProperties": false` (`cannot unmarshal bool ... jsonschema.Schema`).
Nested values-file completion is therefore not a verified working feature for
those charts. Do not remove or weaken schema constraints to hide this error.
Helm CLI schema validation still works, as do template `.Values` completion,
hover and navigation. The sidecar parse error is upstream of this editor policy.

## Deferred investigations

- **AI editor integration:** investigate useful OMP-based editor workflows
  separately. There is no longer a Copilot subscription, the previous Avante
  setup did not work well for this user, and OpenCode has been replaced by OMP.
  Do not restore Copilot or assume that the existing Avante configuration proves
  a working editor workflow.
