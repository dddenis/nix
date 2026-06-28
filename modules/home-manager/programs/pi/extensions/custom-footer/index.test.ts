import { describe, expect, mock, test } from "bun:test";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";

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

describe("custom footer extension", () => {
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

    const ctx = {
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
        setStatus: (_key: string, status?: string) => {
          if (status) statuses.push(status);
        },
      },
    } as unknown as ExtensionContext;

    await handlers.get("session_start")?.({}, ctx);
    await Promise.resolve();

    expect(statuses).toEqual([]);
    expect(footerFactories).toHaveLength(1);

    const footer = footerFactories[0]!({ requestRender() {} } as never, fakeTheme(), {
      getGitBranch: () => "master",
      getExtensionStatuses: () => new Map(),
      getAvailableProviderCount: () => 2,
      onBranchChange: () => () => {},
    } as never);

    const lines = footer.render(160);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toBe("~/project (master) • footer work");
    expect(lines[1]).toContain("81.8% (200k auto) | 5h 99% ↺2h | wk 92% ↺5d");
    expect(lines[1]).toContain("(openai-codex) gpt-5.5 • xhigh");
  });
});
