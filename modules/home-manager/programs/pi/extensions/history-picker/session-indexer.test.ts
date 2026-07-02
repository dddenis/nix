import { describe, expect, test } from "vitest";
import { it } from "@effect/vitest";
import { Deferred, Effect, Layer } from "effect";
import type {
  ExtensionContext,
  SessionInfo,
} from "@earendil-works/pi-coding-agent";

import { SharedServicesTest } from "../shared/test-services";
import { HistoryIndexer } from "./session-indexer";
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

describe("history session indexer", () => {
  test("indexes current session entries through the active context", () => {
    const indexer = new HistoryIndexer();
    const ctx = {
      cwd: "/repo",
      sessionManager: {
        getSessionFile: () => undefined,
        getEntries: () => [
          {
            type: "message",
            id: "a",
            parentId: null,
            timestamp: "2026-06-28T10:00:00.000Z",
            message: { role: "user", content: "current prompt", timestamp: 10 },
          },
        ],
      },
    };

    const items = indexer.indexCurrentSession(ctx as never);

    expect(items.map((item) => [item.text, item.cwd, item.source])).toEqual([
      ["current prompt", "/repo", "current"],
    ]);
  });

  it.effect(
    "indexes current and saved sessions through Effect services",
    () => {
      const files = new Map([
        [
          "/sessions/a.jsonl",
          {
            mtimeMs: 1,
            content: [
              JSON.stringify({ type: "session", cwd: "/repo-a" }),
              JSON.stringify({
                type: "message",
                message: { role: "user", content: "saved", timestamp: 10 },
              }),
            ].join("\n"),
          },
        ],
      ]);

      return Effect.gen(function* () {
        const shared = yield* SharedServicesTest;
        yield* shared.putFile(
          "/sessions/a.jsonl",
          files.get("/sessions/a.jsonl")!,
        );
        const historyServices = yield* HistoryPickerServicesTest;
        yield* historyServices.setSessions([
          session("/sessions/a.jsonl", "/repo-a"),
        ]);

        const indexer = new HistoryIndexer();
        const current = yield* indexer.indexCurrentSessionEffect({
          cwd: "/repo-a",
          sessionManager: {
            getSessionFile: () => undefined,
            getEntries: () => [
              {
                type: "message",
                message: { role: "user", content: "current", timestamp: 20 },
              },
            ],
          },
        } as unknown as ExtensionContext);
        expect(current.map((item) => item.text)).toEqual(["current"]);

        const handle = yield* indexer.startOrJoinSavedSessionRefreshEffect();
        const update = yield* handle.awaitEffect;
        expect(update.items.map((item) => item.text)).toEqual(["saved"]);
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(HistoryPickerServicesTest.layer),
      );
    },
  );

  it.effect("shares one Effect-owned in-flight refresh across joiners", () =>
    Effect.gen(function* () {
      const releaseListing = yield* Deferred.make<void>();
      let listCalls = 0;
      const delayedSessionListing = Layer.succeed(SessionListingService, {
        listAll: () =>
          Effect.sync(() => {
            listCalls += 1;
          }).pipe(
            Effect.zipRight(Deferred.await(releaseListing)),
            Effect.as([session("/sessions/a.jsonl", "/repo-a")]),
          ),
      });

      const shared = yield* SharedServicesTest;
      yield* shared.putFile("/sessions/a.jsonl", {
        mtimeMs: 1,
        content: [
          JSON.stringify({ type: "session", cwd: "/repo-a" }),
          JSON.stringify({
            type: "message",
            message: { role: "user", content: "shared", timestamp: 10 },
          }),
        ].join("\n"),
      });

      const indexer = new HistoryIndexer();
      const program = Effect.gen(function* () {
        const first = yield* indexer.startOrJoinSavedSessionRefreshEffect();
        const second = yield* indexer.startOrJoinSavedSessionRefreshEffect();
        expect(first.promise).toBe(second.promise);

        yield* Deferred.succeed(releaseListing, undefined);
        const firstUpdate = yield* first.awaitEffect;
        const secondUpdate = yield* second.awaitEffect;

        expect(listCalls).toBe(1);
        expect(firstUpdate.items.map((item) => item.text)).toEqual(["shared"]);
        expect(secondUpdate.items.map((item) => item.text)).toEqual(["shared"]);
      });

      yield* program.pipe(Effect.provide(delayedSessionListing));
    }).pipe(Effect.provide(SharedServicesTest.layer)),
  );

  it.effect(
    "reuses unchanged cached saved session files and reparses changed files",
    () =>
      Effect.gen(function* () {
        const shared = yield* SharedServicesTest;
        const historyServices = yield* HistoryPickerServicesTest;
        yield* historyServices.setSessions([
          session("/sessions/a.jsonl", "/repo-a"),
        ]);
        yield* shared.putFile("/sessions/a.jsonl", {
          mtimeMs: 1,
          content: [
            JSON.stringify({ type: "session", cwd: "/repo-a" }),
            JSON.stringify({
              type: "message",
              message: { role: "user", content: "first", timestamp: 10 },
            }),
          ].join("\n"),
        });

        const indexer = new HistoryIndexer();
        let handle = yield* indexer.startOrJoinSavedSessionRefreshEffect();
        yield* handle.awaitEffect;
        expect(
          (yield* indexer.getSavedItemsEffect()).map((item) => item.text),
        ).toEqual(["first"]);

        yield* shared.putFile("/sessions/a.jsonl", {
          mtimeMs: 1,
          content: [
            JSON.stringify({ type: "session", cwd: "/repo-a" }),
            JSON.stringify({
              type: "message",
              message: {
                role: "user",
                content: "should not reparse",
                timestamp: 20,
              },
            }),
          ].join("\n"),
        });

        handle = yield* indexer.startOrJoinSavedSessionRefreshEffect();
        yield* handle.awaitEffect;
        expect(
          (yield* indexer.getSavedItemsEffect()).map((item) => item.text),
        ).toEqual(["first"]);

        yield* shared.putFile("/sessions/a.jsonl", {
          mtimeMs: 2,
          content: [
            JSON.stringify({ type: "session", cwd: "/repo-a" }),
            JSON.stringify({
              type: "message",
              message: { role: "user", content: "second", timestamp: 20 },
            }),
          ].join("\n"),
        });

        handle = yield* indexer.startOrJoinSavedSessionRefreshEffect();
        yield* handle.awaitEffect;
        expect(
          (yield* indexer.getSavedItemsEffect()).map((item) => item.text),
        ).toEqual(["second"]);
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(HistoryPickerServicesTest.layer),
      ),
  );

  it.effect("keeps cached saved items when listing all sessions fails", () =>
    Effect.gen(function* () {
      const shared = yield* SharedServicesTest;
      yield* shared.putFile("/sessions/a.jsonl", {
        mtimeMs: 1,
        content: [
          JSON.stringify({ type: "session", cwd: "/repo-a" }),
          JSON.stringify({
            type: "message",
            message: { role: "user", content: "cached", timestamp: 10 },
          }),
        ].join("\n"),
      });
      const historyServices = yield* HistoryPickerServicesTest;
      yield* historyServices.setSessions([
        session("/sessions/a.jsonl", "/repo-a"),
      ]);

      const indexer = new HistoryIndexer();
      let handle = yield* indexer.startOrJoinSavedSessionRefreshEffect();
      yield* handle.awaitEffect;
      yield* historyServices.setListError(new Error("cannot list sessions"));

      handle = yield* indexer.startOrJoinSavedSessionRefreshEffect();
      const update = yield* handle.awaitEffect;

      expect(update.warning).toBe(
        "Saved sessions unavailable; showing cached and current-session history only.",
      );
      expect(update.items.map((item) => item.text)).toEqual(["cached"]);
    }).pipe(
      Effect.provide(SharedServicesTest.layer),
      Effect.provide(HistoryPickerServicesTest.layer),
    ),
  );
});
