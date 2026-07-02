import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Effect } from "effect";

import {
  EnvironmentService,
  FileSystemService,
  HomeDirectoryService,
  LoggerService,
  ProcessService,
  type SpawnedProcess,
} from "./services";
import { SharedServicesTest } from "./test-services";

describe("shared Effect services", () => {
  it.effect(
    "provides configurable test services through a dual-tag layer",
    () =>
      Effect.gen(function* () {
        const shared = yield* SharedServicesTest;
        yield* shared.setEnv("PI_SUBAGENT_CHILD", "1");
        yield* shared.setHomeDir("/tmp/home");
        yield* shared.addExistingPath("/tmp/home/.pi/agent/sound.mp3");

        const env = yield* EnvironmentService;
        const home = yield* HomeDirectoryService;
        const fs = yield* FileSystemService;
        const logger = yield* LoggerService;

        expect(yield* env.get("PI_SUBAGENT_CHILD")).toBe("1");
        expect(yield* home.get()).toBe("/tmp/home");
        expect(yield* fs.exists("/tmp/home/.pi/agent/sound.mp3")).toBe(true);
        yield* logger.warn("captured warning");

        const state = yield* shared.getState;
        expect(state.warnings).toEqual(["captured warning"]);
      }).pipe(Effect.provide(SharedServicesTest.layer)),
  );

  it.effect("records spawned processes through the test control tag", () =>
    Effect.gen(function* () {
      const shared = yield* SharedServicesTest;
      yield* shared.enqueueSpawnResult({
        killed: false,
        kill: () => true,
        removeAllListeners() {
          return undefined;
        },
        stdin: {},
        stdout: {},
        stderr: {},
        on() {},
        unref() {},
      } as SpawnedProcess);

      const processes = yield* ProcessService;
      const child = yield* processes.spawn("afplay", ["sound.mp3"], {
        detached: true,
        stdio: "ignore",
      });
      expect(child.killed).toBe(false);

      const state = yield* shared.getState;
      expect(state.spawnCalls).toEqual([
        {
          command: "afplay",
          args: ["sound.mp3"],
          options: { detached: true, stdio: "ignore" },
        },
      ]);
    }).pipe(Effect.provide(SharedServicesTest.layer)),
  );
});
