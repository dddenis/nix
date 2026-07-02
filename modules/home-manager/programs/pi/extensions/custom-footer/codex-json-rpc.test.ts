import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Duration, Effect, Fiber, TestClock } from "effect";

import { type SpawnedProcess } from "../shared/services";
import { SharedServicesTest } from "../shared/test-services";
import { readOpenAIRateLimitsEffect } from "./codex-json-rpc";

class FakeChild extends EventEmitter {
  stdin = {
    writes: [] as string[],
    write: (value: string) => {
      this.stdin.writes.push(value);
    },
  };
  stdout = new PassThrough();
  stderr = new PassThrough();
  killed = false;
  killSignal: string | undefined;

  kill(signal: string): boolean {
    this.killed = true;
    this.killSignal = signal;
    return true;
  }

  unref(): void {}
}

function withFakeProcess<A, E, R>(
  child: FakeChild,
  program: Effect.Effect<A, E, R>,
): Effect.Effect<A, E, R> {
  return Effect.gen(function* () {
    const shared = yield* SharedServicesTest;
    yield* shared.enqueueSpawnResult(child as SpawnedProcess);
    return yield* program;
  }).pipe(Effect.provide(SharedServicesTest.layer));
}

describe("Codex JSON-RPC Effect client", () => {
  it.effect(
    "initializes the app-server, reads rate limits, and cleans up",
    () =>
      Effect.gen(function* () {
        const child = new FakeChild();
        const fiber = yield* Effect.fork(
          withFakeProcess(
            child,
            readOpenAIRateLimitsEffect({ timeoutMs: 20_000 }),
          ),
        );
        yield* Effect.yieldNow();

        child.stdout.write(JSON.stringify({ id: 1, result: {} }) + "\n");
        child.stdout.write(
          JSON.stringify({
            id: 2,
            result: {
              rateLimits: {
                limitId: "codex",
                primary: { usedPercent: 1 },
                secondary: { usedPercent: 8 },
              },
              rateLimitsByLimitId: null,
            },
          }) + "\n",
        );

        const result = yield* Fiber.join(fiber);
        expect(result.rateLimits?.limitId).toBe("codex");
        expect(child.stdin.writes[0]).toContain('"method":"initialize"');
        expect(child.stdin.writes[1]).toContain(
          '"method":"account/rateLimits/read"',
        );
        expect(child.killSignal).toBe("SIGTERM");
      }),
  );

  it.effect("fails with JSON-RPC error messages", () =>
    Effect.gen(function* () {
      const child = new FakeChild();
      const fiber = yield* Effect.fork(
        withFakeProcess(
          child,
          readOpenAIRateLimitsEffect({ timeoutMs: 20_000 }),
        ),
      );
      yield* Effect.yieldNow();

      child.stdout.write(JSON.stringify({ id: 1, result: {} }) + "\n");
      child.stdout.write(
        JSON.stringify({
          id: 2,
          error: { message: "rate limits unavailable" },
        }) + "\n",
      );

      const result = yield* Effect.either(Fiber.join(fiber));
      expect(result._tag).toBe("Left");
      if (result._tag === "Left")
        expect(result.left.message).toBe("rate limits unavailable");
      expect(child.killSignal).toBe("SIGTERM");
    }),
  );

  it.effect("includes stderr detail when app-server exits early", () =>
    Effect.gen(function* () {
      const child = new FakeChild();
      const fiber = yield* Effect.fork(
        withFakeProcess(
          child,
          readOpenAIRateLimitsEffect({ timeoutMs: 20_000 }),
        ),
      );
      yield* Effect.yieldNow();
      yield* Effect.promise(
        () => new Promise<void>((resolve) => setImmediate(resolve)),
      );

      child.stderr.write("safehouse locked");
      child.emit("exit", 1, null);

      const result = yield* Effect.either(Fiber.join(fiber));
      expect(result._tag).toBe("Left");
      if (result._tag === "Left") {
        expect(result.left.message).toContain(
          "codex app-server exited before returning rate limits",
        );
        expect(result.left.message).toContain("safehouse locked");
      }
      expect(child.killSignal).toBe("SIGTERM");
    }),
  );

  it.effect("fails and kills the child on timeout through TestClock", () =>
    Effect.gen(function* () {
      yield* TestClock.setTime(new Date(0));
      const child = new FakeChild();
      const fiber = yield* Effect.fork(
        withFakeProcess(child, readOpenAIRateLimitsEffect({ timeoutMs: 20 })),
      );
      yield* Effect.yieldNow();

      yield* TestClock.adjust(Duration.millis(20));

      const result = yield* Effect.either(Fiber.join(fiber));
      expect(result._tag).toBe("Left");
      if (result._tag === "Left")
        expect(result.left.message).toBe(
          "codex app-server timed out after 20ms",
        );
      expect(child.killSignal).toBe("SIGTERM");
    }),
  );
});
