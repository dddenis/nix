import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Duration, Effect, TestClock } from "effect";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

import { SharedServicesTest } from "../shared/test-services";
import { makeRefreshController } from "./refresh-controller";
import { CustomFooterServicesTest } from "./test-services";
import type { AccountRateLimitsResponse } from "./helpers";

function fakeCtx(hasUI = true): ExtensionContext {
  return { hasUI } as ExtensionContext;
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

describe("custom footer refresh controller", () => {
  it.effect(
    "uses TestClock for formatted reset times and min refresh gaps",
    () =>
      Effect.gen(function* () {
        const footerServices = yield* CustomFooterServicesTest;
        yield* footerServices.enqueueRateLimitResponse(response(1));
        yield* footerServices.enqueueJitterMultiplier(1);

        yield* TestClock.setTime(new Date(1_800_000_000_000));
        const controller = yield* makeRefreshController({
          minRefreshGapMs: 30_000,
        });

        yield* controller.refresh(fakeCtx(), { force: true });
        yield* TestClock.adjust(Duration.millis(1_000));
        yield* controller.refresh(fakeCtx());

        expect((yield* footerServices.getState).readCalls).toHaveLength(1);
        expect(yield* controller.getStatus()).toBe(
          "OpenAI 5h 99% ↺2h | wk 92% ↺5d",
        );
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(CustomFooterServicesTest.layer),
      ),
  );

  it.effect(
    "keeps stale status and backs off after a failure using Clock",
    () =>
      Effect.gen(function* () {
        const footerServices = yield* CustomFooterServicesTest;
        yield* footerServices.enqueueRateLimitResponse(response(1));
        yield* footerServices.enqueueReadFailure(
          new Error("503 Service Unavailable"),
        );
        yield* footerServices.enqueueJitterMultiplier(1);

        yield* TestClock.setTime(new Date(1_800_000_000_000));
        const controller = yield* makeRefreshController({
          minRefreshGapMs: 0,
          backoffBaseMs: 60_000,
          backoffMaxMs: 60_000,
        });

        yield* controller.refresh(fakeCtx(), { force: true });
        yield* TestClock.adjust(Duration.millis(1_000));
        yield* controller.refresh(fakeCtx(), { force: true });
        expect(yield* controller.getStatus()).toBe(
          "OpenAI 5h 99% ↺2h | wk 92% ↺5d stale",
        );

        const shared = yield* SharedServicesTest;
        expect((yield* shared.getState).warnings).toEqual([
          "[custom-footer] 503 Service Unavailable",
        ]);

        yield* TestClock.adjust(Duration.millis(1_000));
        yield* controller.refresh(fakeCtx());
        expect((yield* footerServices.getState).readCalls).toHaveLength(2);
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(CustomFooterServicesTest.layer),
      ),
  );

  it.effect("runs interval and wake-delay timers through TestClock", () =>
    Effect.gen(function* () {
      const footerServices = yield* CustomFooterServicesTest;
      yield* footerServices.enqueueRateLimitResponse(response(1));
      yield* footerServices.enqueueRateLimitResponse(response(2));
      yield* footerServices.enqueueJitterMultiplier(1);

      yield* TestClock.setTime(new Date(1_800_000_000_000));
      const controller = yield* makeRefreshController({
        refreshIntervalMs: 5 * 60_000,
        sleepWakeThresholdMs: 60_000,
        wakeRefreshDelayMs: 10_000,
      });

      yield* controller.refresh(fakeCtx(), { force: true });
      yield* controller.startInterval(fakeCtx());
      yield* TestClock.adjust(Duration.millis(5 * 60_000));
      expect((yield* footerServices.getState).readCalls).toHaveLength(1);
      expect(yield* controller.getStatus()).toContain("stale");

      yield* TestClock.adjust(Duration.millis(10_000));
      expect((yield* footerServices.getState).readCalls).toHaveLength(2);
      yield* controller.shutdown();
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(CustomFooterServicesTest.layer),
    ),
  );
});
