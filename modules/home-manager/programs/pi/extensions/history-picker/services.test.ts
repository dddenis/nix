import { describe, expect } from "vitest";
import { it } from "@effect/vitest";
import { Effect } from "effect";
import type { SessionInfo } from "@earendil-works/pi-coding-agent";

import { SessionListingService } from "./services";
import { HistoryPickerServicesTest } from "./test-services";

function session(path: string, cwd: string): SessionInfo {
  return {
    path,
    id: path,
    cwd,
    created: new Date(0),
    modified: new Date(0),
    messageCount: 1,
    firstMessage: "",
    allMessagesText: "",
  };
}

describe("history picker Effect services", () => {
  it.effect("lists sessions through a service layer", () =>
    Effect.gen(function* () {
      const controls = yield* HistoryPickerServicesTest;
      yield* controls.setSessions([session("/sessions/a.jsonl", "/repo-a")]);
      const sessions = yield* SessionListingService;
      expect((yield* sessions.listAll()).map((item) => item.path)).toEqual([
        "/sessions/a.jsonl",
      ]);
      expect((yield* controls.getState).listCalls).toHaveLength(1);
    }).pipe(Effect.provide(HistoryPickerServicesTest.layer)),
  );
});
