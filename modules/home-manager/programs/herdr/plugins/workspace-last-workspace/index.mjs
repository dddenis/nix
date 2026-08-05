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
    if (error?.code === "ENOENT" || error instanceof SyntaxError) return null;
    throw error;
  }
  if (
    !isObject(parsed) ||
    typeof parsed.currentWorkspaceId !== "string" ||
    parsed.currentWorkspaceId.length === 0 ||
    (parsed.previousWorkspaceId !== null &&
      (typeof parsed.previousWorkspaceId !== "string" ||
        parsed.previousWorkspaceId.length === 0))
  ) {
    return null;
  }
  return parsed;
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
  if (required("HERDR_PLUGIN_EVENT") !== "workspace.focused") {
    throw new Error(`unsupported plugin event ${env.HERDR_PLUGIN_EVENT}`);
  }
  let envelope;
  try {
    envelope = JSON.parse(required("HERDR_PLUGIN_EVENT_JSON"));
  } catch (error) {
    throw new Error(`invalid HERDR_PLUGIN_EVENT_JSON: ${error.message}`);
  }
  if (
    envelope?.event !== "workspace_focused" ||
    envelope?.data?.type !== "workspace_focused"
  ) {
    throw new Error("event payload does not match workspace.focused");
  }
  return envelope.data;
}

function workspaceId(value, source) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${source} workspace_id is required`);
  }
  return value;
}

async function recordFocus() {
  const focusedWorkspaceId = workspaceId(
    eventData().workspace_id,
    "event data",
  );
  const path = statePath();
  const history = await readHistory(path);
  if (history?.currentWorkspaceId === focusedWorkspaceId) return;
  await writeHistory(path, {
    currentWorkspaceId: focusedWorkspaceId,
    previousWorkspaceId: history?.currentWorkspaceId ?? null,
  });
}

async function toggle() {
  const actionWorkspaceId = required("HERDR_WORKSPACE_ID");
  const binaryPath = required("HERDR_BIN_PATH");
  const path = statePath();
  const history = await readHistory(path);
  if (!history) return;

  const targetWorkspaceId =
    history.currentWorkspaceId === actionWorkspaceId
      ? history.previousWorkspaceId
      : history.currentWorkspaceId;
  if (!targetWorkspaceId || targetWorkspaceId === actionWorkspaceId) return;

  const listed = runHerdr(binaryPath, ["workspace", "list"], "workspace_list");
  if (
    !Array.isArray(listed.workspaces) ||
    listed.workspaces.some(
      (workspace) =>
        typeof workspace?.workspace_id !== "string" ||
        typeof workspace.focused !== "boolean",
    )
  ) {
    throw new Error("invalid workspace_list response");
  }
  const actionWorkspace = listed.workspaces.find(
    (workspace) => workspace.workspace_id === actionWorkspaceId,
  );
  const targetWorkspace = listed.workspaces.find(
    (workspace) => workspace.workspace_id === targetWorkspaceId,
  );
  if (!actionWorkspace?.focused || !targetWorkspace) return;

  const focused = runHerdr(
    binaryPath,
    ["workspace", "focus", targetWorkspaceId],
    "workspace_info",
  ).workspace;
  if (
    focused?.workspace_id !== targetWorkspaceId ||
    focused.focused !== true
  ) {
    throw new Error(
      `workspace focus returned an unexpected target for ${targetWorkspaceId}`,
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
  process.stderr.write(`workspace-last-workspace: ${error.message}\n`);
  process.exitCode = 1;
}
