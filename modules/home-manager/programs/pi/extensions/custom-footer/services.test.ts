import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Effect } from "effect";

import { JitterService, RateLimitClientService } from "./services";
import { CustomFooterServicesTest } from "./test-services";

describe("custom footer Effect services", () => {
  it.effect("provides rate-limit and jitter services through layers", () =>
    Effect.gen(function* () {
      const controls = yield* CustomFooterServicesTest;
      yield* controls.enqueueRateLimitResponse({
        rateLimits: {
          limitId: "codex",
          primary: { usedPercent: 1 },
          secondary: { usedPercent: 8 },
        },
        rateLimitsByLimitId: null,
      });
      yield* controls.enqueueJitterMultiplier(1);

      const rateLimits = yield* RateLimitClientService;
      const jitter = yield* JitterService;

      expect((yield* rateLimits.read()).rateLimits?.limitId).toBe("codex");
      expect(yield* jitter.nextMultiplier()).toBe(1);
      expect((yield* controls.getState).readCalls).toHaveLength(1);
    }).pipe(Effect.provide(CustomFooterServicesTest.layer)),
  );
});
