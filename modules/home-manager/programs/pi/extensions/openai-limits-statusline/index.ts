import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { createInterface } from "node:readline";
import { homedir } from "node:os";
import { join } from "node:path";

import { formatRateLimitStatus, parseRateLimitsJsonRpcLine, type AccountRateLimitsResponse } from "./helpers";

const STATUS_KEY = "openai-limits";
const REFRESH_INTERVAL_MS = 5 * 60_000;
const MIN_REFRESH_GAP_MS = 30_000;
const APP_SERVER_TIMEOUT_MS = 20_000;

export default function (pi: ExtensionAPI) {
  let timer: ReturnType<typeof setInterval> | undefined;
  let lastRefreshStartedAt = 0;
  let refreshInFlight: Promise<void> | undefined;
  let lastStatus = "OpenAI limits loading";

  const setStatus = (ctx: ExtensionContext, status: string) => {
    lastStatus = status;
    ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("dim", status));
  };

  const refresh = (ctx: ExtensionContext, force = false): Promise<void> => {
    if (!ctx.hasUI) return Promise.resolve();

    const now = Date.now();
    if (!force && now - lastRefreshStartedAt < MIN_REFRESH_GAP_MS) return refreshInFlight ?? Promise.resolve();
    if (refreshInFlight) return refreshInFlight;

    lastRefreshStartedAt = now;
    setStatus(ctx, "OpenAI limits refreshing");

    refreshInFlight = readOpenAIRateLimits()
      .then((response) => setStatus(ctx, formatRateLimitStatus(response)))
      .catch((error) => {
        const message = error instanceof Error ? error.message : String(error);
        setStatus(ctx, `OpenAI limits unavailable`);
        console.warn(`[openai-limits-statusline] ${message}`);
      })
      .finally(() => {
        refreshInFlight = undefined;
      });

    return refreshInFlight;
  };

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    setStatus(ctx, lastStatus);
    void refresh(ctx, true);

    timer = setInterval(() => {
      void refresh(ctx);
    }, REFRESH_INTERVAL_MS);
  });

  pi.on("turn_end", async (_event, ctx) => {
    void refresh(ctx, true);
  });

  pi.on("session_shutdown", async () => {
    if (timer) clearInterval(timer);
    timer = undefined;
  });

  pi.registerCommand("openai-limits", {
    description: "Refresh the OpenAI 5-hour and weekly limits shown in the statusline",
    handler: async (_args, ctx) => {
      await refresh(ctx, true);
      ctx.ui.notify(lastStatus, "info");
    },
  });
}

function findCodexBinary(): string {
  if (process.env.CODEX_BIN) return process.env.CODEX_BIN;

  const directBunInstall = join(homedir(), ".cache", ".bun", "bin", "codex");
  if (existsSync(directBunInstall)) return directBunInstall;

  const nixProfile = join(homedir(), ".nix-profile", "bin", "codex");
  if (existsSync(nixProfile)) return nixProfile;

  return "codex";
}

function readOpenAIRateLimits(): Promise<AccountRateLimitsResponse> {
  const codexBin = findCodexBinary();
  const child = spawn(codexBin, ["app-server", "--stdio"], {
    stdio: ["pipe", "pipe", "pipe"],
    env: process.env,
  });

  const stdout = createInterface({ input: child.stdout });
  let stderr = "";
  let settled = false;
  let initialized = false;

  const initializeRequestId = 1;
  const rateLimitsRequestId = 2;

  const timeout = setTimeout(() => {
    fail(new Error(`codex app-server timed out after ${APP_SERVER_TIMEOUT_MS}ms`));
  }, APP_SERVER_TIMEOUT_MS);

  const send = (payload: unknown) => {
    child.stdin.write(`${JSON.stringify(payload)}\n`);
  };

  const cleanup = () => {
    clearTimeout(timeout);
    stdout.close();
    if (!child.killed) child.kill("SIGTERM");
  };

  const fail = (error: Error) => {
    if (settled) return;
    settled = true;
    cleanup();
    rejectPromise(error);
  };

  let resolvePromise!: (value: AccountRateLimitsResponse) => void;
  let rejectPromise!: (error: Error) => void;

  const promise = new Promise<AccountRateLimitsResponse>((resolve, reject) => {
    resolvePromise = resolve;
    rejectPromise = reject;
  });

  child.stderr.on("data", (chunk) => {
    stderr += String(chunk);
  });

  child.on("error", (error) => {
    fail(error instanceof Error ? error : new Error(String(error)));
  });

  child.on("exit", (code, signal) => {
    if (settled) return;
    const detail = stderr.trim() ? `: ${stderr.trim().slice(0, 500)}` : "";
    fail(new Error(`codex app-server exited before returning rate limits (code=${code}, signal=${signal})${detail}`));
  });

  stdout.on("line", (line) => {
    if (settled) return;

    if (!initialized) {
      if (isJsonRpcResponseFor(line, initializeRequestId)) {
        initialized = true;
        send({ jsonrpc: "2.0", id: rateLimitsRequestId, method: "account/rateLimits/read", params: null });
      }
      return;
    }

    const result = parseRateLimitsJsonRpcLine(line, rateLimitsRequestId);
    if (result) {
      settled = true;
      cleanup();
      resolvePromise(result);
      return;
    }

    const errorMessage = jsonRpcErrorFor(line, rateLimitsRequestId);
    if (errorMessage) fail(new Error(errorMessage));
  });

  send({
    jsonrpc: "2.0",
    id: initializeRequestId,
    method: "initialize",
    params: {
      clientInfo: { name: "pi-openai-limits-statusline", title: "Pi OpenAI Limits Statusline", version: "1" },
      capabilities: {
        experimentalApi: true,
        optOutNotificationMethods: ["remoteControl/status/changed"],
      },
    },
  });

  return promise;
}

function isJsonRpcResponseFor(line: string, requestId: number): boolean {
  try {
    const parsed = JSON.parse(line) as { id?: unknown; result?: unknown };
    return parsed.id === requestId && parsed.result !== undefined;
  } catch {
    return false;
  }
}

function jsonRpcErrorFor(line: string, requestId: number): string | null {
  try {
    const parsed = JSON.parse(line) as { id?: unknown; error?: { message?: unknown } };
    if (parsed.id !== requestId || !parsed.error) return null;
    return typeof parsed.error.message === "string" ? parsed.error.message : JSON.stringify(parsed.error);
  } catch {
    return null;
  }
}
