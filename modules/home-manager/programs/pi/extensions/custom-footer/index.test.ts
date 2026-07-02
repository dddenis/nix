import { it } from "@effect/vitest";
import { Duration, Effect, TestClock } from "effect";
import { describe, expect } from "vitest";
import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";

import { SharedServicesTest } from "../shared/test-services";
import { customFooterExtensionEffect } from "./index";
import { CustomFooterServicesTest } from "./test-services";
import type { AccountRateLimitsResponse } from "./helpers";

type FooterFactory =
  NonNullable<ExtensionContext["ui"]["setFooter"]> extends (
    factory: infer F,
  ) => void
    ? F
    : never;
type CommandHandler = (
  args: string,
  ctx: ExtensionContext,
) => Promise<void> | void;
type EventHandler = (
  event: unknown,
  ctx: ExtensionContext,
) => Promise<void> | void;

function fakeTheme(): Theme {
  return {
    fg: (_name: string, text: string) => text,
    bg: (_name: string, text: string) => text,
    bold: (text: string) => text,
    italic: (text: string) => text,
    strikethrough: (text: string) => text,
  } as Theme;
}

function fakeFooterData(unsubscribes: string[] = []) {
  return {
    getGitBranch: () => "master",
    getExtensionStatuses: () => new Map(),
    getAvailableProviderCount: () => 2,
    onBranchChange: () => () => {
      unsubscribes.push("branch");
    },
  } as never;
}

function fakeContext(
  footerFactories: FooterFactory[],
  notifications: string[] = [],
) {
  return {
    hasUI: true,
    model: {
      id: "gpt-5.5",
      provider: "openai-codex",
      contextWindow: 200_000,
      reasoning: true,
    },
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
    getContextUsage: () => ({
      percent: 18.24,
      contextWindow: 200_000,
      tokens: 36_480,
    }),
    ui: {
      theme: fakeTheme(),
      setFooter: (factory: never) => footerFactories.push(factory),
      setStatus() {},
      notify: (message: string) => notifications.push(message),
    },
  } as unknown as ExtensionContext;
}

function response(usedPercent: number): AccountRateLimitsResponse {
  return {
    rateLimits: {
      limitId: "codex",
      primary: { usedPercent, resetsAt: 1_800_007_200 },
      secondary: { usedPercent: 8, resetsAt: 1_800_432_000 },
    },
    rateLimitsByLimitId: null,
  };
}

function makeHarness() {
  const handlers = new Map<string, EventHandler>();
  const commands = new Map<string, CommandHandler>();
  const footerFactories: FooterFactory[] = [];
  const notifications: string[] = [];
  const pi = {
    on(name, handler) {
      handlers.set(name, handler as EventHandler);
    },
    registerCommand(name, command) {
      commands.set(name, command.handler as CommandHandler);
    },
    getThinkingLevel: () => "xhigh",
  } as unknown as ExtensionAPI;

  return { commands, footerFactories, handlers, notifications, pi };
}

const flushBackground = Effect.yieldNow().pipe(
  Effect.zipRight(Effect.yieldNow()),
  Effect.zipRight(Effect.yieldNow()),
);

function runEvent(
  handlers: Map<string, EventHandler>,
  name: string,
  ctx: ExtensionContext,
): Effect.Effect<void> {
  return Effect.promise(() =>
    Promise.resolve(handlers.get(name)?.({}, ctx)),
  ).pipe(Effect.asVoid);
}

function runCommand(
  commands: Map<string, CommandHandler>,
  name: string,
  ctx: ExtensionContext,
): Effect.Effect<void> {
  return Effect.promise(() =>
    Promise.resolve(commands.get(name)?.("", ctx)),
  ).pipe(Effect.asVoid);
}

describe("custom footer extension", () => {
  it.effect("hides OpenAI limits while the first refresh is pending", () =>
    Effect.gen(function* () {
      const sharedServices = yield* SharedServicesTest;
      yield* sharedServices.setEnv("HOME", "/Users/ddd");
      const footerServices = yield* CustomFooterServicesTest;
      yield* footerServices.enqueueRateLimitResponse(response(1));
      yield* TestClock.setTime(new Date(1_800_000_000_000));

      const harness = makeHarness();
      yield* customFooterExtensionEffect(harness.pi);
      const ctx = fakeContext(harness.footerFactories);
      yield* runEvent(harness.handlers, "session_start", ctx);

      const footer = harness.footerFactories[0]!(
        { requestRender() {} } as never,
        fakeTheme(),
        fakeFooterData(),
      );
      const lineWhilePending = footer.render(160)[1];
      expect(lineWhilePending).not.toContain("loading");
      expect(lineWhilePending).not.toContain("refreshing");
      expect(lineWhilePending).not.toContain("unavailable");

      yield* flushBackground;

      expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d");
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(CustomFooterServicesTest.layer),
    ),
  );

  it.effect("renders OpenAI limits on the stats line", () =>
    Effect.gen(function* () {
      const sharedServices = yield* SharedServicesTest;
      yield* sharedServices.setEnv("HOME", "/Users/ddd");
      const footerServices = yield* CustomFooterServicesTest;
      yield* footerServices.enqueueRateLimitResponse(response(1));
      yield* TestClock.setTime(new Date(1_800_000_000_000));

      const harness = makeHarness();
      yield* customFooterExtensionEffect(harness.pi);
      const ctx = fakeContext(harness.footerFactories);
      yield* runEvent(harness.handlers, "session_start", ctx);
      yield* flushBackground;

      expect(harness.footerFactories).toHaveLength(1);
      const footer = harness.footerFactories[0]!(
        { requestRender() {} } as never,
        fakeTheme(),
        fakeFooterData(),
      );

      const lines = footer.render(160);
      expect(lines).toHaveLength(2);
      expect(lines[0]).toBe("~/project (master) • footer work");
      expect(lines[1]).toContain("81.8% (200k auto) | 5h 99% ↺2h | wk 92% ↺5d");
      expect(lines[1]).toContain("(openai-codex) gpt-5.5 • xhigh");
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(CustomFooterServicesTest.layer),
    ),
  );

  it.effect(
    "keeps stale rate limits after transient failures and backs off repeated refreshes",
    () =>
      Effect.gen(function* () {
        const sharedServices = yield* SharedServicesTest;
        yield* sharedServices.setEnv("HOME", "/Users/ddd");
        const footerServices = yield* CustomFooterServicesTest;
        yield* footerServices.enqueueRateLimitResponse(response(1));
        yield* footerServices.enqueueReadFailure(
          new Error(
            "GET https://chatgpt.com/backend-api/wham/usage failed: 503 Service Unavailable",
          ),
        );
        yield* footerServices.enqueueJitterMultiplier(1);
        yield* TestClock.setTime(new Date(1_800_000_000_000));

        const harness = makeHarness();
        yield* customFooterExtensionEffect(harness.pi);
        const ctx = fakeContext(harness.footerFactories);
        yield* runEvent(harness.handlers, "session_start", ctx);
        yield* flushBackground;

        const footer = harness.footerFactories[0]!(
          { requestRender() {} } as never,
          fakeTheme(),
          fakeFooterData(),
        );
        expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d");

        yield* TestClock.adjust(Duration.millis(1_000));
        yield* runEvent(harness.handlers, "turn_end", ctx);
        yield* flushBackground;

        expect(footer.render(160)[1]).toContain(
          "5h 99% ↺2h | wk 92% ↺5d stale",
        );
        const shared = yield* SharedServicesTest;
        expect((yield* shared.getState).warnings).toEqual([
          "[custom-footer] GET https://chatgpt.com/backend-api/wham/usage failed: 503 Service Unavailable",
        ]);

        yield* TestClock.adjust(Duration.millis(1_000));
        yield* runEvent(harness.handlers, "turn_end", ctx);
        yield* flushBackground;

        expect((yield* footerServices.getState).readCalls).toHaveLength(2);
        expect(footer.render(160)[1]).toContain(
          "5h 99% ↺2h | wk 92% ↺5d stale",
        );
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(CustomFooterServicesTest.layer),
      ),
  );

  it.effect("manual refresh bypasses automatic backoff", () =>
    Effect.gen(function* () {
      const sharedServices = yield* SharedServicesTest;
      yield* sharedServices.setEnv("HOME", "/Users/ddd");
      const footerServices = yield* CustomFooterServicesTest;
      yield* footerServices.enqueueRateLimitResponse(response(1));
      yield* footerServices.enqueueReadFailure(
        new Error(
          "GET https://chatgpt.com/backend-api/wham/usage failed: 503 Service Unavailable",
        ),
      );
      yield* footerServices.enqueueRateLimitResponse(response(3));
      yield* footerServices.enqueueJitterMultiplier(1);
      yield* TestClock.setTime(new Date(1_800_000_000_000));

      const harness = makeHarness();
      yield* customFooterExtensionEffect(harness.pi);
      const ctx = fakeContext(harness.footerFactories, harness.notifications);
      yield* runEvent(harness.handlers, "session_start", ctx);
      yield* flushBackground;

      const footer = harness.footerFactories[0]!(
        { requestRender() {} } as never,
        fakeTheme(),
        fakeFooterData(),
      );
      expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d");

      yield* TestClock.adjust(Duration.millis(1_000));
      yield* runEvent(harness.handlers, "turn_end", ctx);
      yield* flushBackground;
      expect(footer.render(160)[1]).toContain("5h 99% ↺2h | wk 92% ↺5d stale");

      yield* TestClock.adjust(Duration.millis(1_000));
      yield* runCommand(harness.commands, "custom-footer", ctx);

      expect((yield* footerServices.getState).readCalls).toHaveLength(3);
      expect(footer.render(160)[1]).toContain("5h 97%");
      expect(footer.render(160)[1]).toContain("wk 92%");
      expect(harness.notifications.at(-1)).toContain("OpenAI 5h 97%");
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(CustomFooterServicesTest.layer),
    ),
  );

  it.effect("double session_start replaces the previous interval", () =>
    Effect.gen(function* () {
      const sharedServices = yield* SharedServicesTest;
      yield* sharedServices.setEnv("HOME", "/Users/ddd");
      const footerServices = yield* CustomFooterServicesTest;
      yield* footerServices.enqueueRateLimitResponse(response(1));
      yield* footerServices.enqueueRateLimitResponse(response(2));
      yield* footerServices.enqueueRateLimitResponse(response(3));
      yield* TestClock.setTime(new Date(1_800_000_000_000));

      const harness = makeHarness();
      yield* customFooterExtensionEffect(harness.pi);
      const ctx = fakeContext(harness.footerFactories);
      yield* runEvent(harness.handlers, "session_start", ctx);
      yield* flushBackground;
      yield* runEvent(harness.handlers, "session_start", ctx);
      yield* flushBackground;

      expect((yield* footerServices.getState).readCalls).toHaveLength(2);

      yield* TestClock.adjust(Duration.millis(5 * 60_000));
      expect((yield* footerServices.getState).readCalls).toHaveLength(3);
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(CustomFooterServicesTest.layer),
    ),
  );

  it.effect(
    "old footer disposal after a new footer does not clear the active TUI",
    () =>
      Effect.gen(function* () {
        const sharedServices = yield* SharedServicesTest;
        yield* sharedServices.setEnv("HOME", "/Users/ddd");
        const footerServices = yield* CustomFooterServicesTest;
        yield* footerServices.enqueueRateLimitResponse(response(1));
        yield* footerServices.enqueueRateLimitResponse(response(2));
        yield* footerServices.enqueueRateLimitResponse(response(3));
        yield* TestClock.setTime(new Date(1_800_000_000_000));

        const harness = makeHarness();
        yield* customFooterExtensionEffect(harness.pi);
        const ctx = fakeContext(harness.footerFactories);
        yield* runEvent(harness.handlers, "session_start", ctx);
        yield* flushBackground;

        const tui1Renders: string[] = [];
        const tui2Renders: string[] = [];
        const footer1 = harness.footerFactories[0]!(
          { requestRender: () => tui1Renders.push("render") } as never,
          fakeTheme(),
          fakeFooterData(),
        );

        yield* runEvent(harness.handlers, "session_start", ctx);
        yield* flushBackground;
        const footer2 = harness.footerFactories[1]!(
          { requestRender: () => tui2Renders.push("render") } as never,
          fakeTheme(),
          fakeFooterData(),
        );

        tui1Renders.length = 0;
        tui2Renders.length = 0;
        footer1.dispose();
        yield* TestClock.adjust(Duration.millis(1_000));
        yield* runEvent(harness.handlers, "turn_end", ctx);
        yield* flushBackground;

        expect(tui1Renders).toEqual([]);
        expect(tui2Renders).toEqual(["render"]);
        expect(footer2.render(160)[1]).toContain("5h 97%");
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(CustomFooterServicesTest.layer),
      ),
  );

  it.effect(
    "cancels a pending wake-delay refresh when a new session starts",
    () =>
      Effect.gen(function* () {
        const sharedServices = yield* SharedServicesTest;
        yield* sharedServices.setEnv("HOME", "/Users/ddd");
        const footerServices = yield* CustomFooterServicesTest;
        yield* footerServices.enqueueRateLimitResponse(response(1));
        yield* footerServices.enqueueRateLimitResponse(response(2));
        yield* footerServices.enqueueRateLimitResponse(response(3));
        yield* TestClock.setTime(new Date(1_800_000_000_000));

        const harness = makeHarness();
        yield* customFooterExtensionEffect(harness.pi, {
          sleepWakeThresholdMs: 60_000,
          wakeRefreshDelayMs: 10_000,
        });
        const ctx = fakeContext(harness.footerFactories);
        yield* runEvent(harness.handlers, "session_start", ctx);
        yield* flushBackground;

        yield* TestClock.adjust(Duration.millis(5 * 60_000));
        expect((yield* footerServices.getState).readCalls).toHaveLength(1);

        yield* runEvent(harness.handlers, "session_start", ctx);
        yield* flushBackground;
        expect((yield* footerServices.getState).readCalls).toHaveLength(2);

        yield* TestClock.adjust(Duration.millis(10_000));
        expect((yield* footerServices.getState).readCalls).toHaveLength(2);
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(CustomFooterServicesTest.layer),
      ),
  );

  it.effect("session_shutdown interrupts interval refreshes", () =>
    Effect.gen(function* () {
      const sharedServices = yield* SharedServicesTest;
      yield* sharedServices.setEnv("HOME", "/Users/ddd");
      const footerServices = yield* CustomFooterServicesTest;
      yield* footerServices.enqueueRateLimitResponse(response(1));
      yield* footerServices.enqueueRateLimitResponse(response(2));
      yield* TestClock.setTime(new Date(1_800_000_000_000));

      const harness = makeHarness();
      yield* customFooterExtensionEffect(harness.pi);
      const ctx = fakeContext(harness.footerFactories);
      yield* runEvent(harness.handlers, "session_start", ctx);
      yield* flushBackground;
      expect((yield* footerServices.getState).readCalls).toHaveLength(1);

      yield* runEvent(harness.handlers, "session_shutdown", ctx);
      yield* TestClock.adjust(Duration.millis(5 * 60_000));

      expect((yield* footerServices.getState).readCalls).toHaveLength(1);
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(CustomFooterServicesTest.layer),
    ),
  );
});
