import { it } from "@effect/vitest";
import { Effect, Option, TestClock } from "effect";
import { describe, expect, test } from "vitest";

import {
  formatDurationUntil,
  formatRateLimitStatus,
  selectCodexRateLimit,
  parseRateLimitsJsonRpcLine,
  formatRateLimitStatusEffect,
  selectCodexRateLimitEffect,
  type AccountRateLimitsResponse,
} from "./helpers";

const NOW_MS = Date.parse("2026-06-26T16:00:00Z");

describe("OpenAI rate limit helpers", () => {
  test("selects the codex bucket from multi-bucket responses", () => {
    const response: AccountRateLimitsResponse = {
      rateLimits: {
        limitId: "other",
        primary: {
          usedPercent: 50,
          windowDurationMins: 300,
          resetsAt: 1782580000,
        },
        secondary: {
          usedPercent: 20,
          windowDurationMins: 10080,
          resetsAt: 1782978000,
        },
      },
      rateLimitsByLimitId: {
        codex_bengalfox: {
          limitId: "codex_bengalfox",
          primary: {
            usedPercent: 0,
            windowDurationMins: 300,
            resetsAt: 1782584000,
          },
          secondary: {
            usedPercent: 0,
            windowDurationMins: 10080,
            resetsAt: 1783171000,
          },
        },
        codex: {
          limitId: "codex",
          primary: {
            usedPercent: 1,
            windowDurationMins: 300,
            resetsAt: 1782583931,
          },
          secondary: {
            usedPercent: 8,
            windowDurationMins: 10080,
            resetsAt: 1782978425,
          },
        },
      },
    };

    expect(selectCodexRateLimit(response)?.limitId).toBe("codex");
  });

  it.effect("selects and formats Codex rate limits through Effect APIs", () =>
    Effect.gen(function* () {
      const response: AccountRateLimitsResponse = {
        rateLimits: null,
        rateLimitsByLimitId: {
          codex: {
            limitId: "codex",
            primary: {
              usedPercent: 1,
              windowDurationMins: 300,
              resetsAt: Math.floor((NOW_MS + 2 * 3_600_000) / 1000),
            },
            secondary: {
              usedPercent: 8,
              windowDurationMins: 10080,
              resetsAt: Math.floor((NOW_MS + 5 * 86_400_000) / 1000),
            },
          },
        },
      };

      const selected = yield* selectCodexRateLimitEffect(response);
      expect(Option.getOrUndefined(selected)?.limitId).toBe("codex");
      yield* TestClock.setTime(new Date(NOW_MS));
      expect(yield* formatRateLimitStatusEffect(response)).toBe(
        "OpenAI 5h 99% ↺2h | wk 92% ↺5d",
      );
    }),
  );

  test("formats reset durations compactly", () => {
    expect(formatDurationUntil(NOW_MS + 75 * 60_000, NOW_MS)).toBe("1h15m");
    expect(
      formatDurationUntil(NOW_MS + 2 * 86_400_000 + 3 * 3_600_000, NOW_MS),
    ).toBe("2d3h");
    expect(formatDurationUntil(NOW_MS - 60_000, NOW_MS)).toBe("now");
  });

  test("formats 5-hour and weekly limits as remaining percentages", () => {
    const response: AccountRateLimitsResponse = {
      rateLimits: {
        limitId: "codex",
        primary: {
          usedPercent: 1,
          windowDurationMins: 300,
          resetsAt: Math.floor((NOW_MS + 2 * 3_600_000) / 1000),
        },
        secondary: {
          usedPercent: 8,
          windowDurationMins: 10080,
          resetsAt: Math.floor((NOW_MS + 5 * 86_400_000) / 1000),
        },
      },
      rateLimitsByLimitId: null,
    };

    expect(formatRateLimitStatus(response, NOW_MS)).toBe(
      "OpenAI 5h 99% ↺2h | wk 92% ↺5d",
    );
  });

  test("parses account rate limit JSON-RPC result lines", () => {
    const line = JSON.stringify({
      id: 2,
      result: {
        rateLimits: {
          limitId: "codex",
          primary: {
            usedPercent: 1,
            windowDurationMins: 300,
            resetsAt: 1782583931,
          },
          secondary: {
            usedPercent: 8,
            windowDurationMins: 10080,
            resetsAt: 1782978425,
          },
        },
        rateLimitsByLimitId: null,
      },
    });

    expect(parseRateLimitsJsonRpcLine(line, 2)?.rateLimits?.limitId).toBe(
      "codex",
    );
    expect(
      parseRateLimitsJsonRpcLine(JSON.stringify({ id: 1, result: {} }), 2),
    ).toBeNull();
    expect(parseRateLimitsJsonRpcLine("not json", 2)).toBeNull();
  });

  test("accepts partial and nullable rate limit JSON-RPC fields", () => {
    const line = JSON.stringify({
      id: 2,
      result: {
        rateLimits: {
          limitId: null,
          limitName: null,
          primary: {
            usedPercent: 25,
            windowDurationMins: null,
            resetsAt: null,
          },
          secondary: null,
        },
      },
    });

    const parsed = parseRateLimitsJsonRpcLine(line, 2);

    expect(parsed?.rateLimits?.limitId).toBeNull();
    expect(parsed?.rateLimits?.primary?.windowDurationMins).toBeNull();
    expect(formatRateLimitStatus(parsed!, NOW_MS)).toBe("OpenAI 5h 75%");
  });

  test("accepts by-limit-id responses without a top-level rateLimits field", () => {
    const line = JSON.stringify({
      id: 2,
      result: {
        rateLimitsByLimitId: {
          codex: {
            primary: { usedPercent: 1, resetsAt: null },
          },
        },
      },
    });

    const parsed = parseRateLimitsJsonRpcLine(line, 2);

    expect(parsed?.rateLimits).toBeUndefined();
    expect(selectCodexRateLimit(parsed!)?.primary?.usedPercent).toBe(1);
  });
});
