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

export function selectCodexRateLimit(response: AccountRateLimitsResponse): RateLimitSnapshot | null {
  const byId = response.rateLimitsByLimitId;
  if (byId?.codex) return byId.codex;

  const firstCodexBucket = byId
    ? Object.entries(byId).find(([id, snapshot]) => id.startsWith("codex") && snapshot)?.[1]
    : undefined;
  if (firstCodexBucket) return firstCodexBucket;

  return response.rateLimits ?? null;
}

export function formatDurationUntil(targetMs: number, nowMs = Date.now()): string {
  const remainingMs = Math.max(0, targetMs - nowMs);
  if (remainingMs < MINUTE_MS) return "now";

  const days = Math.floor(remainingMs / DAY_MS);
  const hours = Math.floor((remainingMs % DAY_MS) / HOUR_MS);
  const minutes = Math.floor((remainingMs % HOUR_MS) / MINUTE_MS);

  if (days > 0) return hours > 0 ? `${days}d${hours}h` : `${days}d`;
  if (hours > 0) return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
  return `${minutes}m`;
}

export function formatRateLimitStatus(response: AccountRateLimitsResponse, nowMs = Date.now()): string {
  const snapshot = selectCodexRateLimit(response);
  if (!snapshot) return "OpenAI limits unavailable";

  const parts = [formatWindow("5h", snapshot.primary, nowMs), formatWindow("wk", snapshot.secondary, nowMs)].filter(
    (part): part is string => Boolean(part),
  );

  return parts.length > 0 ? `OpenAI ${parts.join(" | ")}` : "OpenAI limits unavailable";
}

export function parseRateLimitsJsonRpcLine(line: string, requestId: number): AccountRateLimitsResponse | null {
  try {
    const parsed = JSON.parse(line) as { id?: unknown; result?: unknown };
    if (parsed.id !== requestId || !parsed.result || typeof parsed.result !== "object") return null;

    const result = parsed.result as AccountRateLimitsResponse;
    return result.rateLimits ? result : null;
  } catch {
    return null;
  }
}

function formatWindow(label: string, window: RateLimitWindow | null | undefined, nowMs: number): string | null {
  if (!window) return null;

  const remainingPercent = Math.max(0, Math.min(100, Math.round(100 - window.usedPercent)));
  const resetSuffix = window.resetsAt ? ` ↺${formatDurationUntil(window.resetsAt * 1000, nowMs)}` : "";
  return `${label} ${remainingPercent}%${resetSuffix}`;
}
