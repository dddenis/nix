import { Data, Effect, Either, Schema } from "effect";

import { runSyncEffect } from "../shared/effect-runtime";
import type { HistoryItem, HistoryItemSource } from "./types";

export const CURRENT_SESSION_FILE = "<current-session>";

const JsonLineSchema = Schema.parseJson();

type AnyRecord = Record<string, unknown>;

export class MalformedSessionJsonlError extends Data.TaggedError(
  "MalformedSessionJsonlError",
)<{
  readonly sessionFile: string;
  readonly lineNumber: number;
}> {
  override get message(): string {
    return `Malformed session JSONL at ${this.sessionFile}:${this.lineNumber}`;
  }
}

function isRecord(value: unknown): value is AnyRecord {
  return typeof value === "object" && value !== null;
}

function extractUserMessageTextSync(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  return content
    .filter((block): block is { type: "text"; text: string } => {
      return (
        isRecord(block) &&
        block.type === "text" &&
        typeof block.text === "string"
      );
    })
    .map((block) => block.text)
    .join("\n");
}

export function extractUserMessageTextEffect(
  content: unknown,
): Effect.Effect<string> {
  return Effect.sync(() => extractUserMessageTextSync(content));
}

export function extractUserMessageText(content: unknown): string {
  return runSyncEffect(extractUserMessageTextEffect(content));
}

function timestampMs(entry: AnyRecord, message: AnyRecord): number {
  if (
    typeof message.timestamp === "number" &&
    Number.isFinite(message.timestamp)
  )
    return message.timestamp;
  if (typeof entry.timestamp === "string") {
    const parsed = Date.parse(entry.timestamp);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function itemFromMessageEntryEffect(
  entry: unknown,
  source: HistoryItemSource,
  sessionFile: string,
  cwd: string,
): Effect.Effect<HistoryItem | null> {
  return Effect.gen(function* () {
    if (!isRecord(entry) || entry.type !== "message") return null;
    const message = entry.message;
    if (!isRecord(message) || message.role !== "user") return null;

    const text = (yield* extractUserMessageTextEffect(message.content)).trim();
    if (text.length === 0) return null;

    return {
      text,
      timestamp: timestampMs(entry, message),
      sessionFile,
      cwd,
      source,
    };
  });
}

export function indexCurrentSessionEntriesEffect(
  entries: readonly unknown[],
  cwd: string,
  sessionFile = CURRENT_SESSION_FILE,
): Effect.Effect<HistoryItem[]> {
  return Effect.gen(function* () {
    const items: HistoryItem[] = [];

    for (const entry of entries) {
      const item = yield* itemFromMessageEntryEffect(
        entry,
        "current",
        sessionFile,
        cwd,
      );
      if (item) items.push(item);
    }

    return items;
  });
}

export function indexCurrentSessionEntries(
  entries: readonly unknown[],
  cwd: string,
  sessionFile = CURRENT_SESSION_FILE,
): HistoryItem[] {
  return runSyncEffect(
    indexCurrentSessionEntriesEffect(entries, cwd, sessionFile),
  );
}

export function parseSavedSessionJsonlEffect(
  content: string,
  sessionFile: string,
  fallbackCwd = "",
): Effect.Effect<HistoryItem[], MalformedSessionJsonlError> {
  return Effect.gen(function* () {
    const lines = content
      .split(/\r?\n/)
      .filter((line) => line.trim().length > 0);
    let cwd = fallbackCwd;
    const items: HistoryItem[] = [];

    for (let index = 0; index < lines.length; index++) {
      const line = lines[index]!;
      const decoded = Schema.decodeUnknownEither(JsonLineSchema)(line);
      if (Either.isLeft(decoded)) {
        return yield* Effect.fail(
          new MalformedSessionJsonlError({
            sessionFile,
            lineNumber: index + 1,
          }),
        );
      }

      const parsed = decoded.right;
      if (!isRecord(parsed)) continue;
      if (parsed.type === "session") {
        if (typeof parsed.cwd === "string") cwd = parsed.cwd;
        continue;
      }

      const item = yield* itemFromMessageEntryEffect(
        parsed,
        "saved",
        sessionFile,
        cwd,
      );
      if (item) items.push(item);
    }

    return items;
  });
}

export function parseSavedSessionJsonl(
  content: string,
  sessionFile: string,
  fallbackCwd = "",
): HistoryItem[] {
  return runSyncEffect(
    parseSavedSessionJsonlEffect(content, sessionFile, fallbackCwd),
  );
}
