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

  # Metro's large web bundle exceeds Node's RAM-derived heap default on the
  # 7 GiB Darwin runner. This is a build budget, not a daemon/agent runtime flag.
  NODE_OPTIONS = "--max-old-space-size=4096";

  # Expo's export catch logs through Metro's asynchronous terminal queue and
  # immediately exits, which can discard the actual bundle error on Darwin.
  preBuild = (old.preBuild or "") + ''
    substituteInPlace node_modules/@expo/cli/build/src/export/exportApp.js \
      --replace-fail '_log.exception(error);' \
      'require("node:fs").writeSync(2, String(error.stack || error) + "\n");'
  '';
})
