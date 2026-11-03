import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
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

const authModule = process.env.PASEO_AUTH_MODULE;
assert.ok(
  authModule,
  "PASEO_AUTH_MODULE must name the pinned daemon's real auth implementation",
);
const { hashDaemonPassword, isBearerTokenValidAsync } = await import(
  pathToFileURL(authModule).href
);

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), "paseo-state-test-"));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const settings = {
    stateDirectory: path.join(root, "state"),
    passwordFile: path.join(root, "password"),
    pluginDirectory: "/nix/store/pinned-plugin/share/paseo-omp",
    tailnetHost: "machine.example.ts.net",
    port: 6767,
    authModule,
    instanceModule: path.join(path.dirname(authModule), "daemon-instance.js"),
  };
  mkdirSync(settings.stateDirectory, { mode: 0o700 });
  return {
    settings,
    config: path.join(settings.stateDirectory, "config.json"),
  };
}

function privatePassword(filename, contents) {
  writeFileSync(filename, contents, { mode: 0o600 });
}

test("restart preserves password, authentication hash, user settings and plugin state", async (t) => {
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
  const password = readFileSync(settings.passwordFile, "utf8");
  const first = readFileSync(config, "utf8");
  const parsed = JSON.parse(first);
  assert.equal(
    await isBearerTokenValidAsync({
      password: parsed.daemon.auth.password,
      token: password.trim(),
    }),
    true,
  );
  assert.equal(
    await isBearerTokenValidAsync({
      password: parsed.daemon.auth.password,
      token: "incorrect",
    }),
    false,
  );
  assert.equal(first.includes(password.trim()), false);
  assert.equal(statSync(settings.passwordFile).mode & 0o777, 0o600);
  assert.equal(statSync(config).mode & 0o777, 0o600);
  await prepare(settings);
  assert.equal(readFileSync(settings.passwordFile, "utf8"), password);
  assert.equal(readFileSync(config, "utf8"), first);
  assert.equal(readFileSync(marker, "utf8"), "persistent plugin settings");
  assert.equal(parsed.agents.idleRuntimeCleanup, false);
  assert.equal(parsed.worktrees.root, "/home/user/worktrees");
  assert.equal(parsed.plugins.other.enabled, false);
});

test("unsafe or empty password files fail without replacing existing config", async (t) => {
  const { settings, config } = fixture(t);
  const original = JSON.stringify({
    version: 1,
    agents: { idleRuntimeCleanup: false },
  });
  writeFileSync(config, original);
  privatePassword(settings.passwordFile, "private-secret\n");
  chmodSync(settings.passwordFile, 0o644);
  await assert.rejects(prepare(settings), /private, user-owned regular file/);
  assert.equal(readFileSync(config, "utf8"), original);
  chmodSync(settings.passwordFile, 0o600);
  writeFileSync(settings.passwordFile, "\n");
  await assert.rejects(prepare(settings), /one nonempty line/);
  assert.equal(readFileSync(config, "utf8"), original);
  rmSync(settings.passwordFile);
  symlinkSync(config, settings.passwordFile);
  await assert.rejects(prepare(settings));
  assert.equal(readFileSync(config, "utf8"), original);
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

test("password-file rotation changes authentication without replacing other state", async (t) => {
  const { settings, config } = fixture(t);
  await prepare(settings);
  const previous = readFileSync(settings.passwordFile, "utf8").trim();
  const replacement = randomBytes(32).toString("base64url");
  privatePassword(settings.passwordFile, replacement);
  await prepare(settings);
  const hash = JSON.parse(readFileSync(config, "utf8")).daemon.auth.password;
  assert.equal(
    await isBearerTokenValidAsync({ password: hash, token: previous }),
    false,
  );
  assert.equal(
    await isBearerTokenValidAsync({ password: hash, token: replacement }),
    true,
  );
});
