import { Clock, Effect, Either, Option, Schema } from "effect";

import { runSyncEffect } from "../shared/effect-runtime";

export interface RateLimitWindow {
  usedPercent: number;
  windowDurationMins?: number | null;
  resetsAt?: number | null;
}

export interface RateLimitSnapshot {
  limitId?: string | null;
  limitName?: string | null;
  primary?: RateLimitWindow | null;
  secondary?: RateLimitWindow | null;
}

export interface AccountRateLimitsResponse {
  rateLimits?: RateLimitSnapshot | null;
  rateLimitsByLimitId?: Record<string, RateLimitSnapshot | undefined> | null;
}

const MINUTE_MS = 60_000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

export function selectCodexRateLimitEffect(
  response: AccountRateLimitsResponse,
): Effect.Effect<Option.Option<RateLimitSnapshot>> {
  return Effect.sync(() => {
    const byId = response.rateLimitsByLimitId;
    if (byId?.codex) return Option.some(byId.codex);

    const firstCodexBucket = byId
      ? Object.entries(byId).find(
          ([id, snapshot]) => id.startsWith("codex") && snapshot,
        )?.[1]
      : undefined;

    return Option.fromNullable(firstCodexBucket ?? response.rateLimits ?? null);
  });
}

export function selectCodexRateLimit(
  response: AccountRateLimitsResponse,
): RateLimitSnapshot | null {
  return Option.getOrNull(runSyncEffect(selectCodexRateLimitEffect(response)));
}

function formatDurationUntilSync(targetMs: number, nowMs: number): string {
  const remainingMs = Math.max(0, targetMs - nowMs);
  if (remainingMs < MINUTE_MS) return "now";

  const days = Math.floor(remainingMs / DAY_MS);
  const hours = Math.floor((remainingMs % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((remainingMs % HOUR_MS) / MINUTE_MS);

  if (days > 0) return hours > 0 ? `${days}d${hours}h` : `${days}d`;
  if (hours > 0) return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
  return `${minutes}m`;
}

export function formatDurationUntilEffect(
  targetMs: number,
): Effect.Effect<string, never, Clock.Clock> {
  return Effect.gen(function* () {
    return formatDurationUntilSync(targetMs, yield* Clock.currentTimeMillis);
  });
}

export function formatDurationUntil(
  targetMs: number,
  nowMs = Date.now(),
): string {
  return formatDurationUntilSync(targetMs, nowMs);
}

function formatWindowEffect(
  label: string,
  window: RateLimitWindow | null | undefined,
): Effect.Effect<string | null, never, Clock.Clock> {
  return Effect.gen(function* () {
    if (!window) return null;
    const remainingPercent = Math.max(
      0,
      Math.min(100, Math.round(100 - window.usedPercent)),
    );
    const resetSuffix = window.resetsAt
      ? ` ↺${yield* formatDurationUntilEffect(window.resetsAt * 1000)}`
      : "";
    return `${label} ${remainingPercent}%${resetSuffix}`;
  });
}

export function formatRateLimitStatusEffect(
  response: AccountRateLimitsResponse,
): Effect.Effect<string, never, Clock.Clock> {
  return Effect.gen(function* () {
    const snapshot = yield* selectCodexRateLimitEffect(response);
    if (Option.isNone(snapshot)) return "OpenAI limits unavailable";

    const parts = [
      yield* formatWindowEffect("5h", snapshot.value.primary),
      yield* formatWindowEffect("wk", snapshot.value.secondary),
    ].filter((part): part is string => Boolean(part));

    return parts.length > 0
      ? `OpenAI ${parts.join(" | ")}`
      : "OpenAI limits unavailable";
  });
}

export function formatRateLimitStatus(
  response: AccountRateLimitsResponse,
  nowMs = Date.now(),
): string {
  const snapshot = selectCodexRateLimit(response);
  if (!snapshot) return "OpenAI limits unavailable";

  const parts = [
    formatWindow("5h", snapshot.primary, nowMs),
    formatWindow("wk", snapshot.secondary, nowMs),
  ].filter((part): part is string => Boolean(part));

  return parts.length > 0
    ? `OpenAI ${parts.join(" | ")}`
    : "OpenAI limits unavailable";
}

const RateLimitWindowSchema = Schema.Struct({
  usedPercent: Schema.Number,
  windowDurationMins: Schema.optional(Schema.NullOr(Schema.Number)),
  resetsAt: Schema.optional(Schema.NullOr(Schema.Number)),
});
const RateLimitSnapshotSchema = Schema.Struct({
  limitId: Schema.optional(Schema.NullOr(Schema.String)),
  limitName: Schema.optional(Schema.NullOr(Schema.String)),
  primary: Schema.optional(Schema.NullOr(RateLimitWindowSchema)),
  secondary: Schema.optional(Schema.NullOr(RateLimitWindowSchema)),
});
const AccountRateLimitsResponseSchema = Schema.Struct({
  rateLimits: Schema.optional(Schema.NullOr(RateLimitSnapshotSchema)),
  rateLimitsByLimitId: Schema.optional(
    Schema.NullOr(
      Schema.Record({
        key: Schema.String,
        value: Schema.UndefinedOr(RateLimitSnapshotSchema),
      }),
    ),
  ),
});
const JsonRpcRateLimitsLineSchema = Schema.parseJson(
  Schema.Struct({
    id: Schema.Number,
    result: Schema.optional(AccountRateLimitsResponseSchema),
  }),
);

export function parseRateLimitsJsonRpcLineEffect(
  line: string,
  requestId: number,
): Effect.Effect<Option.Option<AccountRateLimitsResponse>> {
  return Effect.sync(() => {
    const decoded = Schema.decodeUnknownEither(JsonRpcRateLimitsLineSchema)(
      line,
    );
    if (Either.isLeft(decoded)) return Option.none();
    const parsed = decoded.right;
    if (parsed.id !== requestId || !parsed.result) return Option.none();
    return parsed.result.rateLimits || parsed.result.rateLimitsByLimitId
      ? Option.some(parsed.result)
      : Option.none();
  });
}

export function parseRateLimitsJsonRpcLine(
  line: string,
  requestId: number,
): AccountRateLimitsResponse | null {
  return Option.getOrNull(
    runSyncEffect(parseRateLimitsJsonRpcLineEffect(line, requestId)),
  );
}

function formatWindow(
  label: string,
  window: RateLimitWindow | null | undefined,
  nowMs: number,
): string | null {
  if (!window) return null;

  const remainingPercent = Math.max(
    0,
    Math.min(100, Math.round(100 - window.usedPercent)),
  );
  const resetSuffix = window.resetsAt
    ? ` ↺${formatDurationUntil(window.resetsAt * 1000, nowMs)}`
    : "";
  return `${label} ${remainingPercent}%${resetSuffix}`;
}
