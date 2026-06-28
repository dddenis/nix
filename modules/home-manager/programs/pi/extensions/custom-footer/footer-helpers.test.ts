import { describe, expect, test } from "bun:test";

import {
  buildStatsLine,
  formatInlineOpenAIStatus,
  formatRemainingContextDisplay,
  summarizeAssistantUsage,
  type AssistantUsageEntry,
} from "./footer-helpers";

describe("custom footer helpers", () => {
  test("formats context as remaining percentage with inverted severity", () => {
    expect(
      formatRemainingContextDisplay({ percent: 18.24, contextWindow: 200_000 }, 200_000, true),
    ).toEqual({ text: "81.8% (200k auto)", severity: "normal" });

    expect(formatRemainingContextDisplay({ percent: 75, contextWindow: 200_000 }, 200_000, true)).toEqual({
      text: "25.0% (200k auto)",
      severity: "warning",
    });

    expect(formatRemainingContextDisplay({ percent: 95, contextWindow: 200_000 }, 200_000, false)).toEqual({
      text: "5.0% (200k)",
      severity: "error",
    });

    expect(formatRemainingContextDisplay({ percent: null, contextWindow: 200_000 }, 200_000, true)).toEqual({
      text: "? (200k auto)",
      severity: "unknown",
    });
  });

  test("summarizes assistant usage from all entries", () => {
    const entries: AssistantUsageEntry[] = [
      {
        type: "message",
        message: {
          role: "assistant",
          usage: {
            input: 1_200,
            output: 800,
            cacheRead: 2_000,
            cacheWrite: 400,
            cost: { total: 0.1234 },
          },
        },
      },
      {
        type: "message",
        message: {
          role: "assistant",
          usage: {
            input: 300,
            output: 200,
            cacheRead: 1_000,
            cacheWrite: 0,
            cost: { total: 0.1 },
          },
        },
      },
    ];

    expect(summarizeAssistantUsage(entries)).toEqual({
      input: 1_500,
      output: 1_000,
      cacheRead: 3_000,
      cacheWrite: 400,
      cost: 0.2234,
      latestCacheHitRate: 76.92307692307693,
    });
  });

  test("formats OpenAI status for inline footer display with a separator", () => {
    expect(formatInlineOpenAIStatus("OpenAI 5h 99% ↺2h | wk 92% ↺5d")).toBe("| 5h 99% ↺2h | wk 92% ↺5d");
    expect(formatInlineOpenAIStatus("OpenAI limits loading")).toBe("| loading");
    expect(formatInlineOpenAIStatus("OpenAI limits unavailable")).toBe("| unavailable");
    expect(formatInlineOpenAIStatus("")).toBeNull();
  });

  test("keeps OpenAI limits on the stats line with separator and remaining context", () => {
    const line = buildStatsLine({
      width: 120,
      statsParts: ["↑1.5k", "↓1.0k", "$0.223", "81.8% (200k auto)", "| 5h 99% ↺2h | wk 92% ↺5d"],
      modelName: "gpt-5.5 • xhigh",
      providerName: "openai-codex",
      availableProviderCount: 2,
    });

    expect(line).toContain("81.8% (200k auto) | 5h 99% ↺2h | wk 92% ↺5d");
    expect(line).toContain("(openai-codex) gpt-5.5 • xhigh");
    expect(line.split("\n")).toHaveLength(1);
  });
});
