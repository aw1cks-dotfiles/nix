import {
  chmodSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
} from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";

function privateDirectory(directory) {
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const info = lstatSync(directory);
  if (!info.isDirectory() || info.uid !== process.getuid()) {
    throw new Error(
      `Paseo state directory must be owned by this user: ${directory}`,
    );
  }
  chmodSync(directory, 0o700);
}

// Reconcile nonsecret policy through the daemon's config API. Password loading
// belongs to the exec wrapper; sessions and credentials remain in user storage.
export async function prepare(settings) {
  const { readDaemonInstance } = await import(
    pathToFileURL(settings.instanceModule).href
  );
  if (await readDaemonInstance(settings.stateDirectory)) {
    throw new Error(
      "Paseo is already running for this state directory; stop that instance before enabling managed startup.",
    );
  }
  privateDirectory(settings.stateDirectory);
  const { readPersistedConfig, savePersistedConfig } = await import(
    pathToFileURL(settings.configModule).href
  );
  const config = readPersistedConfig(settings.stateDirectory);
  if (config.daemon?.auth?.password && !existsSync(settings.passwordFile)) {
    throw new Error(
      "Paseo already has a password: provision passwordFile with the existing password before enabling managed startup.",
    );
  }
  config.version = 1;
  config.daemon = {
    ...config.daemon,
    listen: `127.0.0.1:${settings.port}`,
    hostnames: [settings.tailnetHost],
    relay: { ...config.daemon?.relay, enabled: false },
  };
  config.pluginsEnabled = true;
  config.plugins = {
    ...config.plugins,
    "paseo-omp": {
      source: "directory",
      path: settings.pluginDirectory,
      enabled: true,
    },
  };
  savePersistedConfig(settings.stateDirectory, config);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await prepare(JSON.parse(readFileSync(process.argv[2], "utf8")));
}
