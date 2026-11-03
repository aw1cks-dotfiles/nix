{ pkgs, paseoInput }:
(paseoInput.packages.${pkgs.stdenv.hostPlatform.system}.paseo).overrideAttrs (old: {
  # The upstream closure traces daemon processes, but the plugin compiler runs
  # in a separate worker. Trace that graph too, keeping its filesystem-loaded
  # TypeScript assets and esbuild's dynamically selected native executable.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace scripts/trace-daemon.mjs \
      --replace-fail \
        '  "packages/cli/dist/index.js",' \
        '  "packages/server/dist/server/server/plugins/compiler-worker.js",
      "packages/server/dist/server/server/plugins/plugin-process.js",
      "packages/cli/dist/index.js",' \
      --replace-fail \
        'const runtimeDependencies = new Map([' \
        'const runtimeDependencies = new Map([
      ["packages/server/dist/server/server/plugins/compiler-imports.js", ["typescript"]],
      ["packages/server/dist/server/server/plugins/compiler-esbuild.js", ["esbuild"]],' \
      --replace-fail \
        'const additionalInputs = [' \
        'const additionalInputs = [
      resolvedPackageFiles("packages/server/dist/server/server/plugins/compiler-imports.js", "typescript"),
      resolvedPackageFiles("packages/server/dist/server/server/plugins/compiler-esbuild.js", `@esbuild/''${process.platform}-''${process.arch}`),'
  '';
})
