import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Clock, Duration, Effect, Layer, TestClock } from "effect";

import {
  errorToString,
  makeManagedRuntimeRunner,
  runEffectHandler,
  runSyncEffect,
} from "./effect-runtime";

describe("shared Effect runtime adapters", () => {
  it.effect("runs async Effect handlers as promises", () =>
    Effect.gen(function* () {
      const result = yield* Effect.promise(() =>
        runEffectHandler(Effect.succeed("ok")),
      );
      expect(result).toBe("ok");
    }),
  );

  it.effect("runs pure synchronous Effect programs", () =>
    Effect.sync(() => {
      expect(runSyncEffect(Effect.succeed(42))).toBe(42);
    }),
  );

  it.effect("formats unknown errors predictably", () =>
    Effect.sync(() => {
      expect(errorToString(new Error("boom"))).toBe("boom");
      expect(errorToString("plain")).toBe("plain");
      expect(errorToString({ code: "E_TEST" })).toBe('{"code":"E_TEST"}');
      expect(errorToString(undefined)).toBe("undefined");
      expect(errorToString(() => "ignored")).toContain("ignored");
    }),
  );

  it.effect(
    "creates disposable managed runners for long-lived callback boundaries",
    () =>
      Effect.gen(function* () {
        const runner = makeManagedRuntimeRunner(Layer.empty);
        const value = yield* Effect.promise(() =>
          runner.runPromise(Effect.succeed("managed")),
        );
        expect(value).toBe("managed");
        yield* Effect.promise(() => runner.dispose());
      }),
  );

  it.effect("uses Effect TestClock for time-dependent programs", () =>
    Effect.gen(function* () {
      yield* TestClock.setTime(new Date(0));
      const before = yield* Clock.currentTimeMillis;
      const fiber = yield* Effect.fork(Effect.sleep(Duration.millis(1_000)));
      yield* TestClock.adjust(Duration.millis(1_000));
      yield* fiber;
      const after = yield* Clock.currentTimeMillis;

      expect(before).toBe(0);
      expect(after).toBe(1_000);
    }),
  );
});
