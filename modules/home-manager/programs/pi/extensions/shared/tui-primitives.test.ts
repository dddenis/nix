import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Effect } from "effect";

import { TuiPrimitivesService } from "./tui-primitives";
import { TuiPrimitivesTest } from "./test-services";

describe("shared TUI primitive test service", () => {
  it.effect(
    "provides deterministic input, key, width, and truncation primitives",
    () =>
      Effect.gen(function* () {
        const tui = yield* TuiPrimitivesService;
        const input = yield* tui.createInput();
        input.setValue("history");
        input.handleInput(" picker");

        expect(input.getValue()).toBe("history picker");
        expect(tui.matchesKey(tui.key.ctrl("r"), "ctrl+r")).toBe(true);
        expect(tui.visibleWidth("abc")).toBe(3);
        expect(tui.truncateToWidth("abcdef", 4, "…")).toBe("abc…");

        const controls = yield* TuiPrimitivesTest;
        const state = yield* controls.getState;
        expect(state.createdInputs).toHaveLength(1);
        expect(state.createdInputs[0]?.value).toBe("history picker");
      }).pipe(Effect.provide(TuiPrimitivesTest.layer)),
  );
});
