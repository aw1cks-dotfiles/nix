{ pkgs }:
with pkgs;
[
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
  # Prefer the packaged server over rustup's proxy without changing its toolchain.
  (lib.hiPrio rust-analyzer)
  sqls
  taplo
  terraform-ls
  ty
  vscode-langservers-extracted
  yaml-language-server
]
