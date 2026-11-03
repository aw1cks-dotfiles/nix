import { randomBytes } from "node:crypto";
import {
  constants,
  existsSync,
  fstatSync,
  lstatSync,
  mkdirSync,
  openSync,
  closeSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync,
  chmodSync,
} from "node:fs";
import path from "node:path";
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

function passwordFromFile(filename) {
  if (!existsSync(filename)) {
    mkdirSync(path.dirname(filename), { recursive: true, mode: 0o700 });
    try {
      writeFileSync(filename, `${randomBytes(32).toString("base64url")}\n`, {
        flag: "wx",
        mode: 0o600,
      });
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
    }
  }
  const fd = openSync(filename, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const info = fstatSync(fd);
    if (
      !info.isFile() ||
      info.uid !== process.getuid() ||
      (info.mode & 0o077) !== 0
    ) {
      throw new Error(
        `Paseo password must be a private, user-owned regular file: ${filename}`,
      );
    }
    const password = readFileSync(fd, "utf8").trim();
    if (!password || /[\r\n]/.test(password)) {
      throw new Error(
        `Paseo password must contain one nonempty line: ${filename}`,
      );
    }
    return password;
  } finally {
    closeSync(fd);
  }
}

// Only policy-owned config fields are reconciled. Sessions, plugin settings,
// credentials and the one-time password stay in writable user storage.
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
  const filename = path.join(settings.stateDirectory, "config.json");
  const config = existsSync(filename)
    ? JSON.parse(readFileSync(filename, "utf8"))
    : {};
  if (config.daemon?.auth?.password && !existsSync(settings.passwordFile)) {
    throw new Error(
      "Paseo already has a password: provision passwordFile with the existing password before enabling managed startup.",
    );
  }
  const password = passwordFromFile(settings.passwordFile);
  const { hashDaemonPassword, isBearerTokenValidAsync } = await import(
    pathToFileURL(settings.authModule).href
  );
  const previousHash = config.daemon?.auth?.password;
  const passwordHash =
    previousHash &&
    (await isBearerTokenValidAsync({ password: previousHash, token: password }))
      ? previousHash
      : hashDaemonPassword(password);
  config.version = 1;
  config.daemon = {
    ...config.daemon,
    listen: `127.0.0.1:${settings.port}`,
    hostnames: [settings.tailnetHost],
    relay: { ...config.daemon?.relay, enabled: false },
    auth: { password: passwordHash },
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
  const contents = `${JSON.stringify(config, null, 2)}\n`;
  if (existsSync(filename) && readFileSync(filename, "utf8") === contents) {
    chmodSync(filename, 0o600);
    return;
  }
  const temporary = `${filename}.${process.pid}.${randomBytes(6).toString("hex")}`;
  try {
    writeFileSync(temporary, contents, { flag: "wx", mode: 0o600 });
    renameSync(temporary, filename);
  } finally {
    if (existsSync(temporary)) unlinkSync(temporary);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await prepare(JSON.parse(readFileSync(process.argv[2], "utf8")));
}
