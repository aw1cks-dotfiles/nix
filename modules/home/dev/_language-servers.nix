{
  pkgs,
  # Callers pass the analyzer from ./_rust-toolchains.nix.
  rust-analyzer,
}:
with pkgs;
[
  bash-language-server
  # nixpkgs has no standalone clangd; the server ships in clang-tools, whose
  # closure is ~2.1 GB because it pulls clang and llvm.
  clang-tools
  # Neovim configures docker_compose_language_service explicitly; OMP does not
  # (yamlls covers compose there).
  docker-compose-language-service
  dockerfile-language-server
  fsautocomplete
  gopls
  helm-ls
  kotlin-language-server
  lua-language-server
  marksman
  nixd
  omnisharp-roslyn
  python3Packages.ruff
  # One analyzer, toolchain-independent: beat rustup's per-toolchain proxy,
  # which fails for toolchains without the rust-analyzer component.
  (lib.hiPrio rust-analyzer)
  sqls
  taplo
  terraform-ls
  ty
  # tsc's --lsp mode is TypeScript 7+; the pinned tsc 5.9.3 rejects the flag, so
  # OMP drops its typescript-native definition and needs this instead.
  typescript-language-server
  vscode-langservers-extracted
  yaml-language-server
]
