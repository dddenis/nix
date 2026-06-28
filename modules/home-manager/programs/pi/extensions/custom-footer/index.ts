import type { ExtensionAPI, ExtensionContext, ReadonlyFooterDataProvider, Theme } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { createInterface } from "node:readline";
import { homedir } from "node:os";
import { join } from "node:path";

import { formatRateLimitStatus, parseRateLimitsJsonRpcLine, type AccountRateLimitsResponse } from "./helpers";
import {
  buildStatsLine,
  buildUsageStatsParts,
  formatCwdForFooter,
  formatInlineOpenAIStatus,
  formatRemainingContextDisplay,
  summarizeAssistantUsage,
  truncateToWidth,
  type AssistantUsageEntry,
  type RemainingContextDisplay,
} from "./footer-helpers";

const REFRESH_INTERVAL_MS = 5 * 60_000;
const MIN_REFRESH_GAP_MS = 30_000;
const APP_SERVER_TIMEOUT_MS = 20_000;
const AUTO_COMPACT_ENABLED = true;

export interface CustomFooterOptions {
  readRateLimits?: () => Promise<AccountRateLimitsResponse>;
  refreshIntervalMs?: number;
  minRefreshGapMs?: number;
  now?: () => number;
}

export default function (pi: ExtensionAPI) {
  createCustomFooterExtension()(pi);
}

export function createCustomFooterExtension(options: CustomFooterOptions = {}) {
  return function customFooterExtension(pi: ExtensionAPI) {
    const readRateLimits = options.readRateLimits ?? readOpenAIRateLimits;
    const refreshIntervalMs = options.refreshIntervalMs ?? REFRESH_INTERVAL_MS;
    const minRefreshGapMs = options.minRefreshGapMs ?? MIN_REFRESH_GAP_MS;
    const now = options.now ?? Date.now;

    let timer: ReturnType<typeof setInterval> | undefined;
    let lastRefreshStartedAt = 0;
    let refreshInFlight: Promise<void> | undefined;
    let lastStatus = "OpenAI limits loading";
    let activeTui: Pick<TUI, "requestRender"> | undefined;

    const setInlineStatus = (status: string) => {
      lastStatus = status;
      activeTui?.requestRender();
    };

    const refresh = (ctx: ExtensionContext, force = false): Promise<void> => {
      if (!ctx.hasUI) return Promise.resolve();

      const currentTime = now();
      if (!force && currentTime - lastRefreshStartedAt < minRefreshGapMs) {
        return refreshInFlight ?? Promise.resolve();
      }
      if (refreshInFlight) return refreshInFlight;

      lastRefreshStartedAt = currentTime;
      setInlineStatus("OpenAI limits refreshing");

      refreshInFlight = readRateLimits()
        .then((response) => setInlineStatus(formatRateLimitStatus(response, now())))
        .catch((error) => {
          const message = error instanceof Error ? error.message : String(error);
          setInlineStatus("OpenAI limits unavailable");
          console.warn(`[custom-footer] ${message}`);
        })
        .finally(() => {
          refreshInFlight = undefined;
        });

      return refreshInFlight;
    };

    const installFooter = (ctx: ExtensionContext) => {
      ctx.ui.setFooter((tui, theme, footerData) => {
        activeTui = tui;
        const unsubscribeBranch = footerData.onBranchChange(() => tui.requestRender());

        return {
          dispose() {
            unsubscribeBranch();
            if (activeTui === tui) activeTui = undefined;
          },
          invalidate() {},
          render(width: number): string[] {
            return renderFooter(ctx, pi, theme, footerData, lastStatus, width);
          },
        };
      });
    };

    pi.on("session_start", async (_event, ctx) => {
      if (!ctx.hasUI) return;

      if (timer) clearInterval(timer);
      installFooter(ctx);
      void refresh(ctx, true);

      timer = setInterval(() => {
        void refresh(ctx);
      }, refreshIntervalMs);
    });

    pi.on("turn_end", async (_event, ctx) => {
      void refresh(ctx, true);
    });

    pi.on("session_shutdown", async () => {
      if (timer) clearInterval(timer);
      timer = undefined;
      activeTui = undefined;
    });

    pi.registerCommand("custom-footer", {
      description: "Refresh the OpenAI 5-hour and weekly limits shown in the custom footer",
      handler: async (_args, ctx) => {
        await refresh(ctx, true);
        ctx.ui.notify(lastStatus, "info");
      },
    });
  };
}

function renderFooter(
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  openAIStatus: string,
  width: number,
): string[] {
  const pwdLine = renderPwdLine(ctx, theme, footerData, width);
  const statsLine = renderStatsLine(ctx, pi, theme, footerData, openAIStatus, width);
  const lines = [pwdLine, statsLine];

  const extensionStatuses = footerData.getExtensionStatuses();
  if (extensionStatuses.size > 0) {
    const statusLine = Array.from(extensionStatuses.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([, text]) => sanitizeStatusText(text))
      .join(" ");

    if (statusLine) lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
  }

  return lines;
}

function renderPwdLine(
  ctx: ExtensionContext,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  width: number,
): string {
  let pwd = formatCwdForFooter(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);

  const branch = footerData.getGitBranch();
  if (branch) pwd = `${pwd} (${branch})`;

  const sessionName = ctx.sessionManager.getSessionName();
  if (sessionName) pwd = `${pwd} • ${sessionName}`;

  return truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "..."));
}

function renderStatsLine(
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  openAIStatus: string,
  width: number,
): string {
  const entries = ctx.sessionManager.getEntries() as AssistantUsageEntry[];
  const usageSummary = summarizeAssistantUsage(entries);
  const usingSubscription = ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false;
  const contextDisplay = formatRemainingContextDisplay(ctx.getContextUsage(), ctx.model?.contextWindow, AUTO_COMPACT_ENABLED);
  const statsParts = [...buildUsageStatsParts(usageSummary, usingSubscription), contextDisplay.text];

  const inlineOpenAIStatus = formatInlineOpenAIStatus(openAIStatus);
  if (inlineOpenAIStatus) statsParts.push(inlineOpenAIStatus);

  const plainLine = buildStatsLine({
    width,
    statsParts,
    modelName: formatModelName(ctx, pi),
    providerName: ctx.model?.provider,
    availableProviderCount: footerData.getAvailableProviderCount(),
  });

  return styleStatsLine(theme, plainLine, contextDisplay);
}

function formatModelName(ctx: ExtensionContext, pi: ExtensionAPI): string {
  const modelName = ctx.model?.id || "no-model";
  if (!ctx.model?.reasoning) return modelName;

  const thinkingLevel = pi.getThinkingLevel();
  return thinkingLevel === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinkingLevel}`;
}

function styleStatsLine(theme: Theme, plainLine: string, contextDisplay: RemainingContextDisplay): string {
  if (contextDisplay.severity !== "warning" && contextDisplay.severity !== "error") {
    return theme.fg("dim", plainLine);
  }

  const contextStart = plainLine.indexOf(contextDisplay.text);
  if (contextStart < 0) return theme.fg("dim", plainLine);

  const before = plainLine.slice(0, contextStart);
  const after = plainLine.slice(contextStart + contextDisplay.text.length);
  const color = contextDisplay.severity;
  return theme.fg("dim", before) + theme.fg(color, contextDisplay.text) + theme.fg("dim", after);
}

function sanitizeStatusText(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
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
      clientInfo: { name: "pi-custom-footer", title: "Pi Custom Footer", version: "1" },
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
