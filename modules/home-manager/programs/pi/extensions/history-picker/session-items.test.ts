import { it } from "@effect/vitest";
import { Effect } from "effect";
import { describe, expect, test } from "vitest";

import {
  CURRENT_SESSION_FILE,
  MalformedSessionJsonlError,
  extractUserMessageText,
  indexCurrentSessionEntries,
  parseSavedSessionJsonl,
  parseSavedSessionJsonlEffect,
} from "./session-items";

describe("history session items", () => {
  it.effect("parses saved JSONL through an Effect API", () =>
    Effect.gen(function* () {
      const jsonl = [
        JSON.stringify({ type: "session", version: 3, cwd: "/saved-repo" }),
        JSON.stringify({
          type: "message",
          message: { role: "user", content: " saved prompt ", timestamp: 100 },
        }),
      ].join("\n");

      const items = yield* parseSavedSessionJsonlEffect(
        jsonl,
        "/sessions/saved.jsonl",
        "/fallback",
      );
      expect(
        items.map((item) => [item.text, item.cwd, item.timestamp]),
      ).toEqual([["saved prompt", "/saved-repo", 100]]);
    }),
  );

  test("extracts string content and text blocks while ignoring image blocks", () => {
    expect(extractUserMessageText("plain prompt")).toBe("plain prompt");
    expect(
      extractUserMessageText([
        { type: "text", text: "first" },
        { type: "image", data: "base64", mimeType: "image/png" },
        { type: "text", text: "second" },
      ]),
    ).toBe("first\nsecond");
  });

  test("indexes every current-session user message entry supplied by getEntries", () => {
    const entries = [
      {
        type: "message",
        id: "a",
        parentId: null,
        timestamp: "2026-06-28T10:00:00.000Z",
        message: { role: "user", content: "root prompt", timestamp: 10 },
      },
      {
        type: "message",
        id: "b",
        parentId: "a",
        timestamp: "2026-06-28T10:01:00.000Z",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "ignored" }],
          timestamp: 20,
        },
      },
      {
        type: "message",
        id: "c",
        parentId: "a",
        timestamp: "2026-06-28T10:02:00.000Z",
        message: { role: "user", content: "branch prompt", timestamp: 30 },
      },
    ];

    const items = indexCurrentSessionEntries(entries, "/repo");

    expect(items.map((item) => item.text)).toEqual([
      "root prompt",
      "branch prompt",
    ]);
    expect(items.every((item) => item.cwd === "/repo")).toBe(true);
    expect(
      items.every((item) => item.sessionFile === CURRENT_SESSION_FILE),
    ).toBe(true);
    expect(items.every((item) => item.source === "current")).toBe(true);
  });

  test("parses saved JSONL using header cwd and all user-message entries", () => {
    const jsonl = [
      JSON.stringify({ type: "session", version: 3, cwd: "/saved-repo" }),
      JSON.stringify({
        type: "message",
        id: "a",
        parentId: null,
        timestamp: "2026-06-28T10:00:00.000Z",
        message: { role: "user", content: " saved prompt ", timestamp: 100 },
      }),
      JSON.stringify({
        type: "message",
        id: "b",
        parentId: "a",
        timestamp: "2026-06-28T10:01:00.000Z",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "ignored" }],
          timestamp: 200,
        },
      }),
      JSON.stringify({
        type: "message",
        id: "c",
        parentId: "a",
        timestamp: "2026-06-28T10:02:00.000Z",
        message: {
          role: "user",
          content: [{ type: "text", text: "branch" }],
          timestamp: 300,
        },
      }),
    ].join("\n");

    const items = parseSavedSessionJsonl(
      jsonl,
      "/sessions/saved.jsonl",
      "/fallback",
    );

    expect(
      items.map((item) => [
        item.text,
        item.cwd,
        item.timestamp,
        item.sessionFile,
        item.source,
      ]),
    ).toEqual([
      ["saved prompt", "/saved-repo", 100, "/sessions/saved.jsonl", "saved"],
      ["branch", "/saved-repo", 300, "/sessions/saved.jsonl", "saved"],
    ]);
  });

  it.effect(
    "fails malformed saved session JSONL with a tagged domain error",
    () =>
      Effect.gen(function* () {
        const result = yield* Effect.either(
          parseSavedSessionJsonlEffect("{not-json", "/bad.jsonl", "/repo"),
        );

        expect(result._tag).toBe("Left");
        if (result._tag === "Left") {
          expect(result.left).toBeInstanceOf(MalformedSessionJsonlError);
          expect(result.left._tag).toBe("MalformedSessionJsonlError");
          expect(result.left.message).toBe(
            "Malformed session JSONL at /bad.jsonl:1",
          );
        }
      }),
  );

  test("throws on malformed saved session JSONL so the caller can skip the file", () => {
    expect(() =>
      parseSavedSessionJsonl("{not-json", "/bad.jsonl", "/repo"),
    ).toThrow("Malformed session JSONL at /bad.jsonl:1");
  });
});
