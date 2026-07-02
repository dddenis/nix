import { it } from "@effect/vitest";
import { Effect } from "effect";
import { describe, expect, test } from "vitest";

import { TuiPrimitivesService } from "../shared/tui-primitives";
import { TuiPrimitivesTest } from "../shared/test-services";
import { HistoryPickerComponent } from "./picker";
import { HistoryPickerState } from "./picker-state";
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

function plainTheme() {
  return {
    fg: (_role: string, value: string) => value,
    bold: (value: string) => value,
  };
}

describe("history picker state", () => {
  test("uses the initial editor text as query", () => {
    const state = new HistoryPickerState({
      currentCwd: "/repo-a",
      query: "pick",
      currentItems: [item({ text: "history picker", source: "current" })],
      savedItems: [item({ text: "other prompt" })],
    });

    expect(state.query).toBe("pick");
    expect(state.getResults().map((result) => result.item.text)).toEqual([
      "history picker",
    ]);
  });

  it.effect("gets results and selected item through Effect APIs", () =>
    Effect.gen(function* () {
      const state = new HistoryPickerState({
        currentCwd: "/repo-a",
        query: "pick",
        currentItems: [item({ text: "history picker", source: "current" })],
        savedItems: [item({ text: "other prompt" })],
      });

      const results = yield* state.getResultsEffect();
      expect(results.map((result) => result.item.text)).toEqual([
        "history picker",
      ]);
      expect((yield* state.getSelectedItemEffect())?.text).toBe(
        "history picker",
      );
    }),
  );

  test("toggles between all projects and current project", () => {
    const state = new HistoryPickerState({
      currentCwd: "/repo-a",
      query: "",
      currentItems: [
        item({
          text: "local",
          timestamp: 1,
          cwd: "/repo-a",
          source: "current",
        }),
      ],
      savedItems: [item({ text: "remote", timestamp: 2, cwd: "/repo-b" })],
    });

    expect(state.scope).toBe("all");
    expect(state.getResults().map((result) => result.item.text)).toEqual([
      "remote",
      "local",
    ]);

    state.toggleScope();

    expect(state.scope).toBe("current");
    expect(state.getResults().map((result) => result.item.text)).toEqual([
      "local",
    ]);
  });

  test("clamps selection when query changes shrink the result set", () => {
    const state = new HistoryPickerState({
      currentCwd: "/repo-a",
      query: "",
      currentItems: [],
      savedItems: [
        item({ text: "alpha", timestamp: 3 }),
        item({ text: "beta", timestamp: 2 }),
        item({ text: "gamma", timestamp: 1 }),
      ],
    });

    state.moveSelection(2);
    expect(state.selectedIndex).toBe(2);

    state.setQuery("alp");

    expect(state.selectedIndex).toBe(0);
    expect(state.getSelectedItem()?.text).toBe("alpha");
  });
});

describe("history picker component", () => {
  it.effect("renders every visible line within the provided narrow width", () =>
    Effect.gen(function* () {
      const tui = yield* TuiPrimitivesService;
      const input = yield* tui.createInput();
      const state = new HistoryPickerState({
        currentCwd: "/repo-a",
        query: "",
        currentItems: [],
        savedItems: [
          item({
            text: "a long saved prompt that should be truncated",
            timestamp: 1,
          }),
        ],
      });
      const component = new HistoryPickerComponent(
        state,
        plainTheme(),
        () => {},
        () => {},
        tui,
        input,
      );

      const lines = component.render(20);

      expect(lines.length).toBeGreaterThan(0);
      for (const line of lines) {
        expect(tui.visibleWidth(line)).toBeLessThanOrEqual(20);
      }
    }).pipe(Effect.provide(TuiPrimitivesTest.layer)),
  );
});
