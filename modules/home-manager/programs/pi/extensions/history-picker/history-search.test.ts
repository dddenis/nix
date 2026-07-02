import { it } from "@effect/vitest";
import { Effect, Option } from "effect";
import { describe, expect, test } from "vitest";

import {
  searchHistoryItems,
  scoreFuzzy,
  scoreFuzzyEffect,
  searchHistoryItemsEffect,
} from "./history-search";
import type { HistoryItem } from "./types";

function item(overrides: Partial<HistoryItem>): HistoryItem {
  return {
    text: "default prompt",
    timestamp: 1,
    sessionFile: "/sessions/default.jsonl",
    cwd: "/repo-a",
    source: "saved",
    ...overrides,
  };
}

describe("history search", () => {
  it.effect("searches history through Effect APIs", () =>
    Effect.gen(function* () {
      const score = yield* scoreFuzzyEffect("pick", "Open the history picker");
      expect(Option.isSome(score)).toBe(true);

      const results = yield* searchHistoryItemsEffect(
        [
          item({ text: "history picker", timestamp: 100 }),
          item({ text: "unrelated", timestamp: 200 }),
        ],
        "hp",
        "all",
        "/repo-a",
      );
      expect(results.map((result) => result.item.text)).toEqual([
        "history picker",
      ]);
    }),
  );

  test("filters current-project scope before deduplicating by exact trimmed text", () => {
    const results = searchHistoryItems(
      [
        item({ text: "same prompt", timestamp: 100, cwd: "/repo-a" }),
        item({ text: "same prompt", timestamp: 300, cwd: "/repo-b" }),
        item({ text: "newer local prompt", timestamp: 200, cwd: "/repo-a" }),
      ],
      "",
      "current",
      "/repo-a",
    );

    expect(results.map((result) => result.item.text)).toEqual([
      "newer local prompt",
      "same prompt",
    ]);
    expect(results[1]?.item.timestamp).toBe(100);
  });

  test("all-project scope deduplicates exact text to the newest representative", () => {
    const results = searchHistoryItems(
      [
        item({
          text: "same prompt",
          timestamp: 100,
          cwd: "/repo-a",
          sessionFile: "/a.jsonl",
        }),
        item({
          text: "same prompt",
          timestamp: 300,
          cwd: "/repo-b",
          sessionFile: "/b.jsonl",
        }),
        item({ text: "older unique prompt", timestamp: 50, cwd: "/repo-a" }),
      ],
      "",
      "all",
      "/repo-a",
    );

    expect(
      results.map((result) => [result.item.text, result.item.timestamp]),
    ).toEqual([
      ["same prompt", 300],
      ["older unique prompt", 50],
    ]);
  });

  test("fuzzy scorer requires a case-insensitive subsequence and rewards substrings", () => {
    const substring = scoreFuzzy("pick", "Open the history picker");
    const subsequence = scoreFuzzy("hpr", "Open the history picker");

    const hstScore = scoreFuzzy("HST", "history search tool");
    const missingScore = scoreFuzzy("zzz", "history search tool");

    expect(typeof hstScore).toBe("number");
    expect(missingScore).toBeNull();
    expect(typeof substring).toBe("number");
    expect(typeof subsequence).toBe("number");
    expect(substring!).toBeGreaterThan(subsequence!);
  });

  test("non-empty search ranks fuzzy quality before timestamp tie-breakers", () => {
    const results = searchHistoryItems(
      [
        item({ text: "help with picker", timestamp: 500 }),
        item({ text: "history picker", timestamp: 100 }),
        item({ text: "unrelated", timestamp: 1000 }),
      ],
      "hp",
      "all",
      "/repo-a",
    );

    expect(results.map((result) => result.item.text)).toEqual([
      "history picker",
      "help with picker",
    ]);
  });
});
