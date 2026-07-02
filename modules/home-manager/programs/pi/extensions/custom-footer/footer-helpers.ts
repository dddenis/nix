import { isAbsolute, relative, resolve, sep } from "node:path";

import { Effect, Option } from "effect";

import { runSyncEffect } from "../shared/effect-runtime";

export type RemainingContextSeverity =
  "normal" | "warning" | "error" | "unknown";

export interface ContextUsageLike {
  percent: number | null;
  contextWindow: number;
}

export interface RemainingContextDisplay {
  text: string;
  severity: RemainingContextSeverity;
}

export interface AssistantUsageEntry {
  type: string;
  message?: {
    role?: string;
    usage?: {
      input?: number;
      output?: number;
      cacheRead?: number;
      cacheWrite?: number;
      cost?: { total?: number };
    };
  };
}

export interface AssistantUsageSummary {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
  latestCacheHitRate?: number;
}

export interface BuildStatsLineOptions {
  width: number;
  statsParts: string[];
  modelName: string;
  providerName?: string;
  availableProviderCount: number;
}

const ANSI_PATTERN = /\x1b\[[0-9;]*m/g;

export function visibleWidth(value: string): number {
  return [...value.replace(ANSI_PATTERN, "")].length;
}

export function truncateToWidth(
  value: string,
  width: number,
  ellipsis = "...",
): string {
  if (visibleWidth(value) <= width) return value;
  if (width <= 0) return "";
  if (width <= visibleWidth(ellipsis))
    return [...ellipsis].slice(0, width).join("");

  let result = "";
  let consumed = 0;
  for (
    let index = 0;
    index < value.length && consumed < width - visibleWidth(ellipsis);
  ) {
    const escapeMatch = value.slice(index).match(/^\x1b\[[0-9;]*m/);
    if (escapeMatch) {
      result += escapeMatch[0];
      index += escapeMatch[0].length;
      continue;
    }

    const char = [...value.slice(index)][0]!;
    result += char;
    consumed += 1;
    index += char.length;
  }

  return result + ellipsis;
}

export function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
}

export function formatCwdForFooter(
  cwd: string,
  home: string | undefined,
): string {
  if (!home) return cwd;

  const resolvedCwd = resolve(cwd);
  const resolvedHome = resolve(home);
  const relativeToHome = relative(resolvedHome, resolvedCwd);
  const isInsideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." &&
      !relativeToHome.startsWith(`..${sep}`) &&
      !isAbsolute(relativeToHome));

  if (!isInsideHome) return cwd;
  return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

function formatRemainingContextDisplaySync(
  usage: ContextUsageLike | undefined,
  fallbackContextWindow: number | undefined,
  autoCompactEnabled: boolean,
): RemainingContextDisplay {
  const contextWindow = usage?.contextWindow ?? fallbackContextWindow ?? 0;
  const windowText = formatTokens(contextWindow);
  const contextMetadata = autoCompactEnabled
    ? `${windowText} auto`
    : windowText;

  if (!usage || usage.percent === null) {
    return { text: `? (${contextMetadata})`, severity: "unknown" };
  }

  const remainingPercent = Math.max(0, Math.min(100, 100 - usage.percent));
  const severity: RemainingContextSeverity =
    remainingPercent < 10
      ? "error"
      : remainingPercent < 30
        ? "warning"
        : "normal";

  return {
    text: `${remainingPercent.toFixed(1)}% (${contextMetadata})`,
    severity,
  };
}

export function formatRemainingContextDisplayEffect(
  usage: ContextUsageLike | undefined,
  fallbackContextWindow: number | undefined,
  autoCompactEnabled: boolean,
): Effect.Effect<RemainingContextDisplay> {
  return Effect.sync(() =>
    formatRemainingContextDisplaySync(
      usage,
      fallbackContextWindow,
      autoCompactEnabled,
    ),
  );
}

export function formatRemainingContextDisplay(
  usage: ContextUsageLike | undefined,
  fallbackContextWindow: number | undefined,
  autoCompactEnabled: boolean,
): RemainingContextDisplay {
  return runSyncEffect(
    formatRemainingContextDisplayEffect(
      usage,
      fallbackContextWindow,
      autoCompactEnabled,
    ),
  );
}

function summarizeAssistantUsageSync(
  entries: AssistantUsageEntry[],
): AssistantUsageSummary {
  const summary: AssistantUsageSummary = {
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    cost: 0,
  };

  for (const entry of entries) {
    if (entry.type !== "message" || entry.message?.role !== "assistant")
      continue;

    const usage = entry.message.usage;
    if (!usage) continue;

    const input = usage.input ?? 0;
    const output = usage.output ?? 0;
    const cacheRead = usage.cacheRead ?? 0;
    const cacheWrite = usage.cacheWrite ?? 0;

    summary.input += input;
    summary.output += output;
    summary.cacheRead += cacheRead;
    summary.cacheWrite += cacheWrite;
    summary.cost += usage.cost?.total ?? 0;

    const latestPromptTokens = input + cacheRead + cacheWrite;
    summary.latestCacheHitRate =
      latestPromptTokens > 0
        ? (cacheRead / latestPromptTokens) * 100
        : undefined;
  }

  return summary;
}

export function summarizeAssistantUsageEffect(
  entries: AssistantUsageEntry[],
): Effect.Effect<AssistantUsageSummary> {
  return Effect.sync(() => summarizeAssistantUsageSync(entries));
}

export function summarizeAssistantUsage(
  entries: AssistantUsageEntry[],
): AssistantUsageSummary {
  return summarizeAssistantUsageSync(entries);
}

function formatInlineOpenAIStatusSync(status: string): string | null {
  const trimmed = status.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith("OpenAI limits ")) {
    return `| ${trimmed.slice("OpenAI limits ".length)}`;
  }

  if (trimmed.startsWith("OpenAI ")) {
    return `| ${trimmed.slice("OpenAI ".length)}`;
  }

  return `| ${trimmed}`;
}

export function formatInlineOpenAIStatusEffect(
  status: string,
): Effect.Effect<Option.Option<string>> {
  return Effect.sync(() =>
    Option.fromNullable(formatInlineOpenAIStatusSync(status)),
  );
}

export function formatInlineOpenAIStatus(status: string): string | null {
  return formatInlineOpenAIStatusSync(status);
}

function buildUsageStatsPartsSync(
  summary: AssistantUsageSummary,
  usingSubscription: boolean,
): string[] {
  const parts: string[] = [];

  if (summary.input) parts.push(`↑${formatTokens(summary.input)}`);
  if (summary.output) parts.push(`↓${formatTokens(summary.output)}`);
  if (summary.cacheRead) parts.push(`R${formatTokens(summary.cacheRead)}`);
  if (summary.cacheWrite) parts.push(`W${formatTokens(summary.cacheWrite)}`);
  if (
    (summary.cacheRead > 0 || summary.cacheWrite > 0) &&
    summary.latestCacheHitRate !== undefined
  ) {
    parts.push(`CH${summary.latestCacheHitRate.toFixed(1)}%`);
  }
  if (summary.cost || usingSubscription) {
    parts.push(
      `$${summary.cost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`,
    );
  }

  return parts;
}

export function buildUsageStatsPartsEffect(
  summary: AssistantUsageSummary,
  usingSubscription: boolean,
): Effect.Effect<string[]> {
  return Effect.sync(() =>
    buildUsageStatsPartsSync(summary, usingSubscription),
  );
}

export function buildUsageStatsParts(
  summary: AssistantUsageSummary,
  usingSubscription: boolean,
): string[] {
  return buildUsageStatsPartsSync(summary, usingSubscription);
}

function buildStatsLineSync({
  width,
  statsParts,
  modelName,
  providerName,
  availableProviderCount,
}: BuildStatsLineOptions): string {
  const minPadding = 2;
  let statsLeft = statsParts.join(" ");
  let statsLeftWidth = visibleWidth(statsLeft);

  if (statsLeftWidth > width) {
    statsLeft = truncateToWidth(statsLeft, width, "...");
    statsLeftWidth = visibleWidth(statsLeft);
  }

  let rightSide = modelName;
  if (availableProviderCount > 1 && providerName) {
    const providerRightSide = `(${providerName}) ${modelName}`;
    if (
      statsLeftWidth + minPadding + visibleWidth(providerRightSide) <=
      width
    ) {
      rightSide = providerRightSide;
    }
  }

  const rightSideWidth = visibleWidth(rightSide);
  const totalNeeded = statsLeftWidth + minPadding + rightSideWidth;

  if (totalNeeded <= width) {
    return (
      statsLeft +
      " ".repeat(width - statsLeftWidth - rightSideWidth) +
      rightSide
    );
  }

  const availableForRight = width - statsLeftWidth - minPadding;
  if (availableForRight > 0) {
    const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
    const truncatedRightWidth = visibleWidth(truncatedRight);
    return (
      statsLeft +
      " ".repeat(Math.max(0, width - statsLeftWidth - truncatedRightWidth)) +
      truncatedRight
    );
  }

  return statsLeft;
}

export function buildStatsLineEffect(
  options: BuildStatsLineOptions,
): Effect.Effect<string> {
  return Effect.sync(() => buildStatsLineSync(options));
}

export function buildStatsLine(options: BuildStatsLineOptions): string {
  return buildStatsLineSync(options);
}
