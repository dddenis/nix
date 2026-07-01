import { describe, expect, mock, test } from "bun:test";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import type { AccountRateLimitsResponse } from "./helpers";

mock.module("@earendil-works/pi-tui", () => ({
  truncateToWidth: (value: string, width: number, ellipsis = "...") => {
    const stripped = value.replace(/\x1b\[[0-9;]*m/g, "");
    if ([...stripped].length <= width) return value;
    return [...value].slice(0, Math.max(0, width - [...ellipsis].length)).join("") + ellipsis;
  },
  visibleWidth: (value: string) => [...value.replace(/\x1b\[[0-9;]*m/g, "")].length,
}));

function fakeTheme(): Theme {
  return {
    fg: (_name: string, text: string) => text,
    bg: (_name: string, text: string) => text,
    bold: (text: string) => text,
    italic: (text: string) => text,
    strikethrough: (text: string) => text,
  } as Theme;
}

function fakeFooterData() {
  return {
    getGitBranch: () => "master",
    getExtensionStatuses: () => new Map(),
    getAvailableProviderCount: () => 2,
    onBranchChange: () => () => {},
  } as never;
}

function fakeContext(
  footerFactories: Array<NonNullable<ExtensionContext["ui"]["setFooter"]> extends (factory: infer F) => void ? F : never>,
) {
  return {
    hasUI: true,
    model: { id: "gpt-5.5", provider: "openai-codex", contextWindow: 200_000, reasoning: true },
    sessionManager: {
      getCwd: () => "/Users/ddd/project",
      getSessionName: () => "footer work",
      getEntries: () => [
        {
          type: "message",
          message: {
            role: "assistant",
            usage: {
              input: 1_200,
              output: 800,
              cacheRead: 0,
              cacheWrite: 0,
              cost: { total: 0.12 },
            },
          },
        },
      ],
    },
    modelRegistry: { isUsingOAuth: () => false },
    getContextUsage: () => ({ percent: 18.24, contextWindow: 200_000, tokens: 36_480 }),
    ui: {
      theme: fakeTheme(),
      setFooter: (factory: never) => footerFactories.push(factory),
      setStatus() {},
    },
  } as unknown as ExtensionContext;
}

async function flushPromises(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}

function createDeferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((promiseResolve, promiseReject) => {
    resolve = promiseResolve;
    reject = promiseReject;
  });
  return { promise, resolve, reject };
}

describe("custom footer extension", () => {
  test("hides OpenAI limits while the first refresh is pending", async () => {
    const { createCustomFooterExtension } = await import("./index");
    const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void> | void>();
    const footerFactories: Array<NonNullable<ExtensionContext["ui"]["setFooter"]> extends (factory: infer F) => void ? F : never> = [];
    const deferred = createDeferred<AccountRateLimitsResponse>();

    createCustomFooterExtension({
      readRateLimits: () => deferred.promise,
      refreshIntervalMs: 60 * 60_000,
      minRefreshGapMs: 0,
      now: () => 1_800_000_000_000,
    })({
      on(name, handler) {
        handlers.set(name, handler as (event: unknown, ctx: ExtensionContext) => Promise<void> | void);
      },
      registerCommand() {},
      getThinkingLevel: () => "xhigh",
    } as unknown as ExtensionAPI);

    const ctx = fakeContext(footerFactories);
    await handlers.get("session_start")?.({}, ctx);

    const footer = footerFactories[0]!({ requestRender() {} } as never, fakeTheme(), fakeFooterData());
    const lineWhilePending = footer.render(160)[1];
    expect(lineWhilePending).not.toContain("loading");
    expect(lineWhilePending).not.toContain("refreshing");
    expect(lineWhilePending).not.toContain("unavailable");

    deferred.resolve({
      rateLimits: {
        limitId: "codex",
        primary: { usedPercent: 1, resetsAt: 1_800_007_200 },
        secondary: { usedPercent: 8, resetsAt: 1_800_432_000 },
      },
      rateLimitsByLimitId: null,
    });
    await flushPromises();

    expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d");
  });

  test("replaces the footer and renders OpenAI limits on the stats line", async () => {
    const { createCustomFooterExtension } = await import("./index");
    const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void> | void>();
    const footerFactories: Array<NonNullable<ExtensionContext["ui"]["setFooter"]> extends (factory: infer F) => void ? F : never> = [];
    const statuses: string[] = [];

    createCustomFooterExtension({
      readRateLimits: async () => ({
        rateLimits: {
          limitId: "codex",
          primary: { usedPercent: 1, resetsAt: 1_800_007_200 },
          secondary: { usedPercent: 8, resetsAt: 1_800_432_000 },
        },
        rateLimitsByLimitId: null,
      }),
      refreshIntervalMs: 60 * 60_000,
      minRefreshGapMs: 0,
      now: () => 1_800_000_000_000,
    })({
      on(name, handler) {
        handlers.set(name, handler as (event: unknown, ctx: ExtensionContext) => Promise<void> | void);
      },
      registerCommand() {},
      getThinkingLevel: () => "xhigh",
    } as unknown as ExtensionAPI);

    const ctx = fakeContext(footerFactories) as ExtensionContext;
    ctx.ui.setStatus = (_key: string, status?: string) => {
      if (status) statuses.push(status);
    };

    await handlers.get("session_start")?.({}, ctx);
    await flushPromises();

    expect(statuses).toEqual([]);
    expect(footerFactories).toHaveLength(1);

    const footer = footerFactories[0]!({ requestRender() {} } as never, fakeTheme(), fakeFooterData());

    const lines = footer.render(160);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe("~/project (master) • footer work");
    expect(lines[1]).toContain("81.8% (200k auto) | 5h 99% ↺2h | wk 92% ↺5d");
    expect(lines[1]).toContain("(openai-codex) gpt-5.5 • xhigh");
  });

  test("keeps stale rate limits after transient failures and backs off repeated refreshes", async () => {
    const { createCustomFooterExtension } = await import("./index");
    const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void> | void>();
    const footerFactories: Array<NonNullable<ExtensionContext["ui"]["setFooter"]> extends (factory: infer F) => void ? F : never> = [];
    const warnings: string[] = [];
    let attempts = 0;
    let nowMs = 1_800_000_000_000;

    createCustomFooterExtension({
      readRateLimits: async () => {
        attempts += 1;
        if (attempts === 1) {
          return {
            rateLimits: {
              limitId: "codex",
              primary: { usedPercent: 1, resetsAt: 1_800_007_200 },
              secondary: { usedPercent: 8, resetsAt: 1_800_432_000 },
            },
            rateLimitsByLimitId: null,
          };
        }
        throw new Error("GET https://chatgpt.com/backend-api/wham/usage failed: 503 Service Unavailable");
      },
      refreshIntervalMs: 60 * 60_000,
      minRefreshGapMs: 0,
      backoffBaseMs: 60_000,
      warningDebounceMs: 60_000,
      now: () => nowMs,
      logger: { warn: (message: string) => warnings.push(message) },
    })({
      on(name, handler) {
        handlers.set(name, handler as (event: unknown, ctx: ExtensionContext) => Promise<void> | void);
      },
      registerCommand() {},
      getThinkingLevel: () => "xhigh",
    } as unknown as ExtensionAPI);

    const ctx = fakeContext(footerFactories);
    await handlers.get("session_start")?.({}, ctx);
    await flushPromises();

    const footer = footerFactories[0]!({ requestRender() {} } as never, fakeTheme(), fakeFooterData());
    expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d");

    nowMs += 1_000;
    await handlers.get("turn_end")?.({}, ctx);
    await flushPromises();

    expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d stale");
    expect(warnings).toHaveLength(1);

    nowMs += 1_000;
    await handlers.get("turn_end")?.({}, ctx);
    await flushPromises();

    expect(attempts).toBe(2);
    expect(warnings).toHaveLength(1);
    expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d stale");
  });

  test("manual refresh bypasses automatic backoff", async () => {
    const { createCustomFooterExtension } = await import("./index");
    const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void> | void>();
    const commands = new Map<string, (args: string, ctx: ExtensionContext) => Promise<void> | void>();
    const footerFactories: Array<NonNullable<ExtensionContext["ui"]["setFooter"]> extends (factory: infer F) => void ? F : never> = [];
    const notifications: string[] = [];
    let attempts = 0;
    let nowMs = 1_800_000_000_000;

    createCustomFooterExtension({
      readRateLimits: async () => {
        attempts += 1;
        if (attempts === 2) {
          throw new Error("GET https://chatgpt.com/backend-api/wham/usage failed: 503 Service Unavailable");
        }
        return {
          rateLimits: {
            limitId: "codex",
            primary: { usedPercent: attempts, resetsAt: 1_800_007_200 },
            secondary: { usedPercent: 8, resetsAt: 1_800_432_000 },
          },
          rateLimitsByLimitId: null,
        };
      },
      refreshIntervalMs: 60 * 60_000,
      minRefreshGapMs: 0,
      backoffBaseMs: 60_000,
      now: () => nowMs,
      logger: { warn() {} },
    })({
      on(name, handler) {
        handlers.set(name, handler as (event: unknown, ctx: ExtensionContext) => Promise<void> | void);
      },
      registerCommand(name, command) {
        commands.set(name, command.handler as (args: string, ctx: ExtensionContext) => Promise<void> | void);
      },
      getThinkingLevel: () => "xhigh",
    } as unknown as ExtensionAPI);

    const ctx = fakeContext(footerFactories) as ExtensionContext;
    ctx.ui.notify = (message: string) => notifications.push(message);
    await handlers.get("session_start")?.({}, ctx);
    await flushPromises();

    const footer = footerFactories[0]!({ requestRender() {} } as never, fakeTheme(), fakeFooterData());
    expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d");

    nowMs += 1_000;
    await handlers.get("turn_end")?.({}, ctx);
    await flushPromises();
    expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d stale");

    nowMs += 1_000;
    await commands.get("custom-footer")?.("", ctx);
    await flushPromises();

    expect(attempts).toBe(3);
    expect(footer.render(160)[1]).toContain("5h 97%");
    expect(footer.render(160)[1]).toContain("wk 92%");
    expect(notifications.at(-1)).toContain("OpenAI 5h 97%");
  });

  test("delays interval refresh after a detected wake from sleep", async () => {
    const { createCustomFooterExtension } = await import("./index");
    const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void> | void>();
    const footerFactories: Array<NonNullable<ExtensionContext["ui"]["setFooter"]> extends (factory: infer F) => void ? F : never> = [];
    const intervalCallbacks: Array<() => void> = [];
    const timeoutCallbacks: Array<{ ms: number; callback: () => void }> = [];
    let nowMs = 1_800_000_000_000;
    let attempts = 0;

    createCustomFooterExtension({
      readRateLimits: async () => {
        attempts += 1;
        return {
          rateLimits: {
            limitId: "codex",
            primary: { usedPercent: attempts, resetsAt: 1_800_007_200 },
            secondary: { usedPercent: 8, resetsAt: 1_800_432_000 },
          },
          rateLimitsByLimitId: null,
        };
      },
      refreshIntervalMs: 5 * 60_000,
      minRefreshGapMs: 0,
      sleepWakeThresholdMs: 60_000,
      wakeRefreshDelayMs: 10_000,
      now: () => nowMs,
      setIntervalFn: (callback: () => void) => {
        intervalCallbacks.push(callback);
        return 1;
      },
      clearIntervalFn() {},
      setTimeoutFn: (callback: () => void, ms: number) => {
        timeoutCallbacks.push({ callback, ms });
        return 2;
      },
      clearTimeoutFn() {},
    })({
      on(name, handler) {
        handlers.set(name, handler as (event: unknown, ctx: ExtensionContext) => Promise<void> | void);
      },
      registerCommand() {},
      getThinkingLevel: () => "xhigh",
    } as unknown as ExtensionAPI);

    const ctx = fakeContext(footerFactories);
    await handlers.get("session_start")?.({}, ctx);
    await flushPromises();

    expect(attempts).toBe(1);
    expect(intervalCallbacks).toHaveLength(1);

    nowMs += 5 * 60_000;
    intervalCallbacks[0]!();
    await flushPromises();

    expect(attempts).toBe(1);
    expect(timeoutCallbacks).toHaveLength(1);
    expect(timeoutCallbacks[0]!.ms).toBe(10_000);

    timeoutCallbacks[0]!.callback();
    await flushPromises();

    expect(attempts).toBe(2);
  });
});
