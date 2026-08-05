#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

const env = process.env;

function required(name) {
  const value = env[name];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function statePath() {
  const stateDir = required("HERDR_PLUGIN_STATE_DIR");
  const socketHash = createHash("sha256")
    .update(required("HERDR_SOCKET_PATH"))
    .digest("hex");
  return join(stateDir, `history-${socketHash}.json`);
}

async function readHistory(path) {
  let parsed;
  try {
    parsed = JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    if (error?.code === "ENOENT" || error instanceof SyntaxError) return {};
    throw error;
  }
  if (!isObject(parsed)) return {};
  return Object.fromEntries(
    Object.entries(parsed).filter(
      ([, record]) =>
        isObject(record) &&
        typeof record.currentTabId === "string" &&
        record.currentTabId.length > 0 &&
        (record.previousTabId === null ||
          (typeof record.previousTabId === "string" &&
            record.previousTabId.length > 0)),
    ),
  );
}

async function writeHistory(path, history) {
  await mkdir(dirname(path), { recursive: true });
  const temporaryPath = `${path}.${process.pid}.${randomUUID()}.tmp`;
  try {
    await writeFile(temporaryPath, `${JSON.stringify(history, null, 2)}\n`, {
      encoding: "utf8",
      mode: 0o600,
    });
    await rename(temporaryPath, path);
  } catch (error) {
    await rm(temporaryPath, { force: true });
    throw error;
  }
}

function runHerdr(binaryPath, args, expectedType) {
  const socketPath = required("HERDR_SOCKET_PATH");
  const completed = spawnSync(binaryPath, args, {
    encoding: "utf8",
    env: { ...env, HERDR_SOCKET_PATH: socketPath },
    shell: false,
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 2_000,
  });
  const command = `herdr ${args.join(" ")}`;
  if (completed.error) {
    throw new Error(`${command} failed: ${completed.error.message}`);
  }
  if (completed.status !== 0) {
    const detail = (completed.stderr ?? "").trim().slice(-1_000);
    throw new Error(
      `${command} failed with status ${completed.status}: ${detail}`,
    );
  }
  let response;
  try {
    response = JSON.parse(completed.stdout);
  } catch (error) {
    throw new Error(`${command} returned malformed JSON: ${error.message}`);
  }
  if (response.error) {
    throw new Error(
      `${command} failed: ${response.error.message ?? "unknown API error"}`,
    );
  }
  if (response.result?.type !== expectedType) {
    throw new Error(
      `${command} returned ${response.result?.type ?? "no result"}`,
    );
  }
  return response.result;
}

function eventData() {
  if (required("HERDR_PLUGIN_EVENT") !== "tab.focused") {
    throw new Error(`unsupported plugin event ${env.HERDR_PLUGIN_EVENT}`);
  }
  let envelope;
  try {
    envelope = JSON.parse(required("HERDR_PLUGIN_EVENT_JSON"));
  } catch (error) {
    throw new Error(`invalid HERDR_PLUGIN_EVENT_JSON: ${error.message}`);
  }
  if (
    envelope?.event !== "tab_focused" ||
    envelope?.data?.type !== "tab_focused"
  ) {
    throw new Error("event payload does not match tab.focused");
  }
  return envelope.data;
}

function eventId(data, name) {
  const value = data[name];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`event data.${name} is required`);
  }
  return value;
}

async function recordFocus() {
  const data = eventData();
  const workspaceId = eventId(data, "workspace_id");
  const tabId = eventId(data, "tab_id");
  const path = statePath();
  const history = await readHistory(path);
  const existing = history[workspaceId];
  if (existing?.currentTabId === tabId) return;
  history[workspaceId] = {
    currentTabId: tabId,
    previousTabId: existing?.currentTabId ?? null,
  };
  await writeHistory(path, history);
}

async function toggle() {
  const workspaceId = required("HERDR_WORKSPACE_ID");
  const actionTabId = required("HERDR_TAB_ID");
  const binaryPath = required("HERDR_BIN_PATH");
  const history = await readHistory(statePath());
  const record = history[workspaceId];
  if (!record) return;

  const targetTabId =
    record.currentTabId === actionTabId
      ? record.previousTabId
      : record.currentTabId;
  if (!targetTabId || targetTabId === actionTabId) return;

  const listed = runHerdr(
    binaryPath,
    ["tab", "list", "--workspace", workspaceId],
    "tab_list",
  );
  if (
    !Array.isArray(listed.tabs) ||
    listed.tabs.some(
      (tab) =>
        typeof tab?.tab_id !== "string" || tab.workspace_id !== workspaceId,
    )
  ) {
    throw new Error(`invalid tab_list response for ${workspaceId}`);
  }
  const target = listed.tabs.find(
    (tab) => tab?.tab_id === targetTabId && tab.workspace_id === workspaceId,
  );
  if (!target) return;

  const inspected = runHerdr(
    binaryPath,
    ["workspace", "get", workspaceId],
    "workspace_info",
  ).workspace;
  if (
    inspected?.workspace_id !== workspaceId ||
    typeof inspected.focused !== "boolean" ||
    typeof inspected.active_tab_id !== "string"
  ) {
    throw new Error(`invalid workspace_info response for ${workspaceId}`);
  }
  if (!inspected.focused || inspected.active_tab_id !== actionTabId) return;

  const focused = runHerdr(
    binaryPath,
    ["tab", "focus", targetTabId],
    "tab_info",
  ).tab;
  if (
    focused?.tab_id !== targetTabId ||
    focused?.workspace_id !== workspaceId
  ) {
    throw new Error(
      `tab focus returned an unexpected target for ${targetTabId}`,
    );
  }
}

try {
  if (env.HERDR_PLUGIN_ACTION_ID === "toggle") {
    await toggle();
  } else if (env.HERDR_PLUGIN_EVENT) {
    await recordFocus();
  } else {
    throw new Error("missing plugin action or event context");
  }
} catch (error) {
  process.stderr.write(`workspace-last-tab: ${error.message}\n`);
  process.exitCode = 1;
}
