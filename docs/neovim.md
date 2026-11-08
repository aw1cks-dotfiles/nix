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

Only the standalone Rust analyzer has higher package priority, to beat rustup's
`rust-analyzer` proxy when both enter the user environment. Rustup still owns its
compiler and Cargo proxies. Existing editor runtimes, formatters, debuggers, and
upstream automatic extra dependencies remain unchanged; repeated references to
the same store output are not separate installations. The server atom alone does
not provision every project's toolchain or dependencies.

OMP uses its native definitions and supported project-local bin directories
before PATH; missing executables are skipped rather than installed. Startup root
markers are checked in the current working directory, not ancestors. Merely
providing executables does not register new OMP servers: the pinned definitions
do not cover our Docker Compose, F#, Kotlin, SQL, or TOML servers. OMP's Kotlin
definition expects the different `kotlin-lsp` implementation; its C# definition
expects lowercase `omnisharp`, whereas our package provides `OmniSharp`.
No aliases, command overrides, or generated OMP LSP configuration bridge these
differences.

This shares binaries, not running server processes or Neovim's server settings.
Terminal OMP needs the HM profile on PATH; managed Paseo already adds it, and
Avante ACP inherits Neovim's wrapper environment. Other GUI launchers, services,
and ACP clients need their own environment setup. Zed remains independently
configured. Package provisioning is not a blanket offline guarantee.

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
| `sindrets/diffview.nvim` | `pkgs.vimPlugins.diffview-nvim` |
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
