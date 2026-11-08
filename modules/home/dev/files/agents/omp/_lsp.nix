# OMP adds file-type and root-marker filtering on top of its built-in LSP
# definitions; a server only starts when the working directory contains one of
# its root markers. Nixpkgs provides several servers whose OMP definition is
# missing, mismatched, or absent, so this file holds the fragments we need.
#
# Every entry is merged over the matching built-in definition by name (OMP's
# merge is `{ ...builtin, ...override }`), so only the differing keys belong
# here. Names absent from the built-in set are registered as new servers.
{
  # Built-in, but the package ships an uppercase `OmniSharp`.
  omnisharp = {
    command = "OmniSharp";
  };

  # Built-in as `kotlin-lsp` (the newer JetBrains server). nixpkgs ships
  # `kotlin-language-server`, which speaks stdio with no arguments; the
  # built-in `--stdio` flag makes it exit immediately.
  "kotlin-lsp" = {
    command = "kotlin-language-server";
    args = [ ];
  };

  # yamlls provides YAML syntax and compose-spec schema diagnostics. Its
  # built-in .git marker misses standalone Compose directories, so retain it
  # and add only Compose basenames; ordinary YAML still needs a Git root.
  yamlls = {
    rootMarkers = [
      ".git"
      "docker-compose.yml"
      "docker-compose.yaml"
      "compose.yml"
      "compose.yaml"
    ];
  };

  # `dockerls` stays built-in-only: it claims `Dockerfile` by basename, and
  # `fileTypes` matches extensions or exact basenames without wildcards, so the
  # `Dockerfile.*` variants it misses cannot be expressed here.

  # Not in the built-in set. `*.toml` as a root marker lets taplo work in a
  # directory that has no other TOML-rooted project file.
  taplo = {
    command = "taplo";
    args = [
      "lsp"
      "stdio"
    ];
    fileTypes = [ ".toml" ];
    rootMarkers = [ "*.toml" ];
  };

  # sqls is deliberately absent. It advertises no `diagnosticProvider` and
  # without a database connection never pushes diagnostics, so OMP's
  # `diagnostics` action waits forever instead of returning. Enable it
  # per-consumer with `lspServers.sqls` only where that is acceptable.

  # Not in the built-in set. OMP does not send F# workspace-selection requests,
  # so let fsautocomplete load the restored projects automatically.
  fsharp = {
    command = "fsautocomplete";
    args = [ "--stdio" ];
    initOptions.AutomaticWorkspaceInit = true;
    fileTypes = [
      ".fs"
      ".fsi"
      ".fsx"
    ];
    rootMarkers = [
      "*.fsproj"
      "*.sln"
    ];
  };
}
