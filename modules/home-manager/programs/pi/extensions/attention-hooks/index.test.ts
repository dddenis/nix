import { describe, expect, test } from "vitest";
import { it } from "@effect/vitest";
import { Effect } from "effect";

import { type SpawnedProcess } from "../shared/services";
import { SharedServicesTest } from "../shared/test-services";
import * as attentionHooks from "./index";
import {
  SOUND_FILE_NAME,
  getCompletionSoundPath,
  playCompletionSound,
  shouldPlayCompletionSound,
} from "./index";

type TestPi = {
  on: (
    event: string,
    handler: (event: {
      messages: Array<{ role?: string; stopReason?: string }>;
    }) => unknown,
  ) => void;
  events: {
    on: (event: string, handler: (payload: unknown) => unknown) => () => void;
  };
};

type RegisterAttentionHooksForTest = (
  pi: TestPi,
  options?: { env?: { PI_SUBAGENT_CHILD?: string }; playSound?: () => void },
) => void;

function getRegisterAttentionHooks(): RegisterAttentionHooksForTest {
  const registerAttentionHooks = (
    attentionHooks as { registerAttentionHooks?: RegisterAttentionHooksForTest }
  ).registerAttentionHooks;

  expect(typeof registerAttentionHooks).toBe("function");

  return registerAttentionHooks!;
}

function createPiHarness(): {
  pi: TestPi;
  emitAgentEnd: (
    messages: Array<{ role?: string; stopReason?: string }>,
  ) => Promise<void>;
  emitControlEvent: (payload: unknown) => void;
} {
  const agentHandlers = new Map<
    string,
    Array<
      (event: {
        messages: Array<{ role?: string; stopReason?: string }>;
      }) => unknown
    >
  >();
  const eventHandlers = new Map<string, Array<(payload: unknown) => unknown>>();

  return {
    pi: {
      on(event, handler) {
        const handlers = agentHandlers.get(event) ?? [];
        handlers.push(handler);
        agentHandlers.set(event, handlers);
      },
      events: {
        on(event, handler) {
          const handlers = eventHandlers.get(event) ?? [];
          handlers.push(handler);
          eventHandlers.set(event, handlers);
          return () => {
            const currentHandlers = eventHandlers.get(event) ?? [];
            eventHandlers.set(
              event,
              currentHandlers.filter(
                (currentHandler) => currentHandler !== handler,
              ),
            );
          };
        },
      },
    },
    async emitAgentEnd(messages) {
      for (const handler of agentHandlers.get("agent_end") ?? [])
        await handler({ messages });
    },
    emitControlEvent(payload) {
      for (const handler of eventHandlers.get("subagent:control-event") ?? [])
        handler(payload);
    },
  };
}

describe("attention hooks", () => {
  it.effect(
    "exposes Effect-first decision APIs through EnvironmentService",
    () =>
      Effect.gen(function* () {
        const shared = yield* SharedServicesTest;
        yield* shared.setEnv("PI_SUBAGENT_CHILD", "1");

        expect(
          yield* attentionHooks.shouldPlayCompletionSoundEffect([
            { role: "assistant", stopReason: "stop" },
          ]),
        ).toBe(true);
        expect(
          yield* attentionHooks.shouldPlayCompletionSoundEffect([
            { role: "assistant", stopReason: "aborted" },
          ]),
        ).toBe(false);
        expect(
          yield* attentionHooks.shouldPlayAgentEndSoundEffect([
            { role: "assistant", stopReason: "stop" },
          ]),
        ).toBe(false);
        expect(
          yield* attentionHooks.shouldPlaySubagentControlSoundEffect({
            event: { type: "needs_attention" },
          }),
        ).toBe(false);
      }).pipe(Effect.provide(SharedServicesTest.layer)),
  );

  it.effect("plays the existing Pi sound through Effect services", () => {
    const soundPath = `/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`;
    const child = {
      on() {},
      removeAllListeners() {
        return undefined;
      },
      unref() {},
      killed: false,
      kill: () => true,
    } as SpawnedProcess;

    return Effect.gen(function* () {
      const shared = yield* SharedServicesTest;
      yield* shared.setHomeDir("/Users/ddd");
      yield* shared.addExistingPath(soundPath);
      yield* shared.enqueueSpawnResult(child);

      yield* attentionHooks.playCompletionSoundEffect();

      const state = yield* shared.getState;
      expect(state.spawnCalls).toEqual([
        {
          command: "afplay",
          args: [soundPath],
          options: { detached: true, stdio: "ignore" },
        },
      ]);
    }).pipe(Effect.provide(SharedServicesTest.layer));
  });

  test("does not play an agent-end sound from a subagent child process", async () => {
    const registerAttentionHooks = getRegisterAttentionHooks();
    const harness = createPiHarness();
    const soundCalls: string[] = [];

    registerAttentionHooks(harness.pi, {
      env: { PI_SUBAGENT_CHILD: "1" },
      playSound: () => soundCalls.push("sound"),
    });

    await harness.emitAgentEnd([{ role: "assistant", stopReason: "stop" }]);

    expect(soundCalls).toEqual([]);
  });

  test("plays when a subagent control event needs attention", () => {
    const registerAttentionHooks = getRegisterAttentionHooks();
    const harness = createPiHarness();
    const soundCalls: string[] = [];

    registerAttentionHooks(harness.pi, {
      playSound: () => soundCalls.push("sound"),
    });

    harness.emitControlEvent({ event: { type: "needs_attention" } });

    expect(soundCalls).toEqual(["sound"]);
  });

  test("does not play a subagent control sound from a subagent child process", () => {
    const registerAttentionHooks = getRegisterAttentionHooks();
    const harness = createPiHarness();
    const soundCalls: string[] = [];

    registerAttentionHooks(harness.pi, {
      env: { PI_SUBAGENT_CHILD: "1" },
      playSound: () => soundCalls.push("sound"),
    });

    harness.emitControlEvent({ event: { type: "needs_attention" } });

    expect(soundCalls).toEqual([]);
  });

  test("does not duplicate subagent attention sounds when hooks are registered again", () => {
    const registerAttentionHooks = getRegisterAttentionHooks();
    const harness = createPiHarness();
    const soundCalls: string[] = [];

    registerAttentionHooks(harness.pi, {
      playSound: () => soundCalls.push("sound"),
    });
    registerAttentionHooks(harness.pi, {
      playSound: () => soundCalls.push("sound"),
    });

    harness.emitControlEvent({ event: { type: "needs_attention" } });

    expect(soundCalls).toEqual(["sound"]);
  });

  test("plays when the agent finishes without an aborted assistant message", () => {
    expect(
      shouldPlayCompletionSound([{ role: "assistant", stopReason: "stop" }]),
    ).toBe(true);
  });

  test("plays when the agent finishes with an assistant error", () => {
    expect(
      shouldPlayCompletionSound([{ role: "assistant", stopReason: "error" }]),
    ).toBe(true);
  });

  test("does not play when the final assistant message was aborted", () => {
    expect(
      shouldPlayCompletionSound([
        { role: "assistant", stopReason: "stop" },
        { role: "user" },
        { role: "assistant", stopReason: "aborted" },
      ]),
    ).toBe(false);
  });

  test("uses only the Pi agent sound file path", () => {
    const homeDir = "/Users/ddd";

    expect(getCompletionSoundPath(homeDir)).toBe(
      `/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`,
    );
  });

  test("does not spawn afplay when the Pi agent sound file is missing", () => {
    const homeDir = "/Users/ddd";
    const checkedPaths: string[] = [];
    const spawnCalls: string[] = [];

    playCompletionSound({
      homeDir,
      existsSync: (path) => {
        checkedPaths.push(path);
        return path.includes("/.claude/") || path.includes("/.codex/");
      },
      spawn: (command) => {
        spawnCalls.push(command);
        return {};
      },
    });

    expect(checkedPaths).toEqual([`/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`]);
    expect(spawnCalls).toEqual([]);
  });

  test("plays the existing Pi agent sound without blocking", () => {
    const homeDir = "/Users/ddd";
    const soundPath = `/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`;
    let unrefCalled = false;
    let errorHandlerRegistered = false;
    let spawnCall: unknown;

    playCompletionSound({
      homeDir,
      existsSync: (path) => path === soundPath,
      spawn: (command, args, options) => {
        spawnCall = { command, args, options };
        return {
          on(event: string) {
            if (event === "error") errorHandlerRegistered = true;
            return this;
          },
          unref() {
            unrefCalled = true;
          },
        };
      },
    });

    expect(spawnCall).toEqual({
      command: "afplay",
      args: [soundPath],
      options: { detached: true, stdio: "ignore" },
    });
    expect(errorHandlerRegistered).toBe(true);
    expect(unrefCalled).toBe(true);
  });

  test("silently ignores afplay spawn failures", () => {
    expect(() =>
      playCompletionSound({
        homeDir: "/Users/ddd",
        existsSync: () => true,
        spawn: () => {
          throw new Error("afplay unavailable");
        },
      }),
    ).not.toThrow();
  });
});
