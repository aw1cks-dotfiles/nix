import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";
import { prepare } from "./prepare.mjs";

const serverDirectory = process.env.PASEO_SERVER_DIRECTORY;
const passwordCommand = process.env.PASEO_PASSWORD_COMMAND;
assert.ok(serverDirectory, "PASEO_SERVER_DIRECTORY must name the pinned daemon");
assert.ok(passwordCommand, "PASEO_PASSWORD_COMMAND must name the built launcher");
const { hashDaemonPassword, isBearerTokenValidAsync } = await import(
  pathToFileURL(path.join(serverDirectory, "auth.js")).href
);

// Exercise the real daemon's environment-over-config authentication precedence.
const resolveAuthentication = `
  const { readPersistedConfig, resolveConfigFromPersisted } = await import(
    ${JSON.stringify(pathToFileURL(path.join(serverDirectory, "config.js")).href)}
  );
  const config = resolveConfigFromPersisted(
    process.env.PASEO_HOME, readPersistedConfig(process.env.PASEO_HOME)
  );
  console.log(JSON.stringify(config.auth));
`;

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), "paseo-state-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const settings = {
    stateDirectory: path.join(root, "state"),
    passwordFile: path.join(root, "password"),
    pluginDirectory: "/nix/store/pinned-plugin/share/paseo-omp",
    tailnetHost: "machine.example.ts.net",
    port: 6767,
    configModule: path.join(serverDirectory, "config.js"),
    instanceModule: path.join(serverDirectory, "daemon-instance.js"),
  };
  mkdirSync(settings.stateDirectory, { mode: 0o700 });
  return {
    settings,
    config: path.join(settings.stateDirectory, "config.json"),
  };
}

function launch(settings) {
  return spawnSync(
    passwordCommand,
    [
      settings.passwordFile,
      process.execPath,
      "--input-type=module",
      "-e",
      resolveAuthentication,
    ],
    {
      encoding: "utf8",
      env: {
        ...process.env,
        PASEO_HOME: settings.stateDirectory,
        PASEO_PASSWORD: "inherited-value-must-not-win",
      },
    },
  );
}

function authentication(settings) {
  const result = launch(settings);
  assert.equal(result.status, 0, result.stderr || String(result.error));
  return JSON.parse(result.stdout);
}

test("restart preserves the password and user state without persisting a managed hash", async (t) => {
  const { settings, config } = fixture(t);
  const marker = path.join(settings.stateDirectory, "plugin-settings-marker");
  writeFileSync(marker, "persistent plugin settings");
  writeFileSync(
    config,
    JSON.stringify({
      version: 1,
      agents: { idleRuntimeCleanup: false },
      worktrees: { root: "/home/user/worktrees" },
      plugins: {
        other: {
          source: "directory",
          path: "/home/user/plugin",
          enabled: false,
        },
      },
    }),
  );
  await prepare(settings);
  const firstAuth = authentication(settings);
  const password = readFileSync(settings.passwordFile, "utf8");
  const first = readFileSync(config, "utf8");
  assert.equal(
    await isBearerTokenValidAsync({ ...firstAuth, token: password.trim() }),
    true,
  );
  assert.equal(
    await isBearerTokenValidAsync({ ...firstAuth, token: "incorrect" }),
    false,
  );
  assert.equal(JSON.parse(first).daemon.auth, undefined);
  assert.equal(first.includes(password.trim()), false);
  assert.equal(statSync(settings.passwordFile).mode & 0o777, 0o600);
  assert.equal(statSync(config).mode & 0o777, 0o600);
  await prepare(settings);
  const nextAuth = authentication(settings);
  assert.equal(
    await isBearerTokenValidAsync({ ...nextAuth, token: password.trim() }),
    true,
  );
  assert.equal(readFileSync(settings.passwordFile, "utf8"), password);
  assert.equal(readFileSync(config, "utf8"), first);
  assert.equal(readFileSync(marker, "utf8"), "persistent plugin settings");
  const parsed = JSON.parse(first);
  assert.equal(parsed.agents.idleRuntimeCleanup, false);
  assert.equal(parsed.worktrees.root, "/home/user/worktrees");
  assert.equal(parsed.plugins.other.enabled, false);
});

test("unsafe, empty and multiline password files refuse startup", (t) => {
  const { settings } = fixture(t);
  writeFileSync(settings.passwordFile, "private-secret\n", { mode: 0o600 });
  chmodSync(settings.passwordFile, 0o644);
  let result = launch(settings);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /private, user-owned regular file/);
  chmodSync(settings.passwordFile, 0o600);
  for (const contents of ["\n", " \t\n", "first\nsecond\n"]) {
    writeFileSync(settings.passwordFile, contents);
    result = launch(settings);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /one nonempty line/);
    assert.equal(readFileSync(settings.passwordFile, "utf8"), contents);
  }
  rmSync(settings.passwordFile);
  const target = path.join(settings.stateDirectory, "secret");
  writeFileSync(target, "private-secret\n", { mode: 0o600 });
  symlinkSync(target, settings.passwordFile);
  result = launch(settings);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /private, user-owned regular file/);
  assert.equal(readFileSync(target, "utf8"), "private-secret\n");
});

test("adopting an existing password requires explicit secret provisioning", async (t) => {
  const { settings, config } = fixture(t);
  const original = JSON.stringify({
    version: 1,
    daemon: { auth: { password: hashDaemonPassword("existing-password") } },
  });
  writeFileSync(config, original);
  await assert.rejects(prepare(settings), /already has a password/);
  assert.equal(existsSync(settings.passwordFile), false);
  assert.equal(readFileSync(config, "utf8"), original);
});

test("password-file rotation overrides an existing persisted hash", async (t) => {
  const { settings, config } = fixture(t);
  const previousHash = hashDaemonPassword("existing-password");
  writeFileSync(
    config,
    JSON.stringify({
      version: 1,
      daemon: { auth: { password: previousHash } },
      worktrees: { root: "/home/user/worktrees" },
    }),
  );
  writeFileSync(settings.passwordFile, "existing-password\n", { mode: 0o600 });
  await prepare(settings);
  const before = authentication(settings);
  assert.equal(
    await isBearerTokenValidAsync({ ...before, token: "existing-password" }),
    true,
  );
  writeFileSync(settings.passwordFile, "replacement-password\n");
  const after = authentication(settings);
  assert.equal(
    await isBearerTokenValidAsync({ ...after, token: "existing-password" }),
    false,
  );
  assert.equal(
    await isBearerTokenValidAsync({ ...after, token: "replacement-password" }),
    true,
  );
  const parsed = JSON.parse(readFileSync(config, "utf8"));
  assert.equal(parsed.daemon.auth.password, previousHash);
  assert.equal(parsed.worktrees.root, "/home/user/worktrees");
});

test("configuration reconciliation accepts upstream-supported UTF-8 BOM files", async (t) => {
  const { settings, config } = fixture(t);
  writeFileSync(
    config,
    "\uFEFF" +
      JSON.stringify({
        version: 1,
        worktrees: { root: "/home/user/worktrees" },
      }),
  );
  await prepare(settings);
  assert.equal(
    JSON.parse(readFileSync(config, "utf8")).worktrees.root,
    "/home/user/worktrees",
  );
});

test("password file contents are data rather than executable shell syntax", async (t) => {
  const { settings } = fixture(t);
  await prepare(settings);
  const marker = path.join(settings.stateDirectory, "must-not-exist");
  const password = `literal-$(touch '${marker}')`;
  writeFileSync(settings.passwordFile, `${password}\n`, { mode: 0o600 });
  const auth = authentication(settings);
  assert.equal(
    await isBearerTokenValidAsync({ ...auth, token: password }),
    true,
  );
  assert.equal(existsSync(marker), false);
});
