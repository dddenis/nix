import type {
  ExtensionAPI,
  ExtensionContext,
  ReadonlyFooterDataProvider,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { Clock, Effect, Layer, Runtime } from "effect";

import { runSyncEffect } from "../shared/effect-runtime";
import { EnvironmentService, SharedLiveLayer } from "../shared/services";
import {
  buildStatsLine,
  buildUsageStatsParts,
  formatCwdForFooter,
  formatInlineOpenAIStatus,
  formatRemainingContextDisplay,
  summarizeAssistantUsage,
  truncateToWidth,
  type AssistantUsageEntry,
  type RemainingContextDisplay,
} from "./footer-helpers";
import {
  makeRefreshController,
  type RefreshControllerConfig,
} from "./refresh-controller";
import {
  CustomFooterLiveLayer,
  JitterService,
  RateLimitClientService,
} from "./services";

const REFRESH_INTERVAL_MS = 5 * 60_000;
const MIN_REFRESH_GAP_MS = 30_000;
const AUTO_COMPACT_ENABLED = true;
const BACKOFF_BASE_MS = 60_000;
const BACKOFF_MAX_MS = 15 * 60_000;
const WAKE_REFRESH_DELAY_MS = 45_000;

const CustomFooterRuntimeLayer = Layer.mergeAll(
  SharedLiveLayer,
  CustomFooterLiveLayer,
);

export default function (pi: ExtensionAPI) {
  createCustomFooterExtension()(pi);
}

export function customFooterExtensionEffect(
  pi: ExtensionAPI,
  controllerConfigOverrides: Partial<RefreshControllerConfig> = {},
): Effect.Effect<
  void,
  never,
  EnvironmentService | RateLimitClientService | JitterService | Clock.Clock
> {
  return Effect.gen(function* () {
    const runtime = yield* Effect.runtime<
      EnvironmentService | RateLimitClientService | JitterService | Clock.Clock
    >();
    const controller = yield* makeRefreshController({
      refreshIntervalMs: REFRESH_INTERVAL_MS,
      minRefreshGapMs: MIN_REFRESH_GAP_MS,
      backoffBaseMs: BACKOFF_BASE_MS,
      backoffMaxMs: BACKOFF_MAX_MS,
      sleepWakeThresholdMs: REFRESH_INTERVAL_MS + 60_000,
      wakeRefreshDelayMs: WAKE_REFRESH_DELAY_MS,
      ...controllerConfigOverrides,
    });
    const run = <A, E>(
      program: Effect.Effect<
        A,
        E,
        | EnvironmentService
        | RateLimitClientService
        | JitterService
        | Clock.Clock
      >,
    ) => Runtime.runPromise(runtime)(program);

    const installFooter = (ctx: ExtensionContext) => {
      const home = Runtime.runSync(runtime)(resolveFooterHomeEffect());

      ctx.ui.setFooter((tui, theme, footerData) => {
        Runtime.runSync(runtime)(controller.setActiveTui(tui));
        const unsubscribeBranch = footerData.onBranchChange(() =>
          tui.requestRender(),
        );
        return {
          dispose() {
            unsubscribeBranch();
            Runtime.runSync(runtime)(controller.clearActiveTui(tui));
          },
          invalidate() {},
          render(width: number): string[] {
            return renderFooter(
              ctx,
              pi,
              theme,
              footerData,
              Runtime.runSync(runtime)(controller.getStatus()),
              home,
              width,
            );
          },
        };
      });
    };

    yield* Effect.sync(() => {
      pi.on("session_start", async (_event, ctx) => {
        if (!ctx.hasUI) return;
        await run(controller.shutdown());
        installFooter(ctx);
        void run(controller.refresh(ctx, { force: true }));
        await run(controller.startInterval(ctx));
      });

      pi.on("turn_end", async (_event, ctx) => {
        void run(controller.refresh(ctx, { force: true }));
      });

      pi.on("session_shutdown", async () => {
        await run(controller.shutdown());
      });

      pi.registerCommand("custom-footer", {
        description:
          "Refresh the OpenAI 5-hour and weekly limits shown in the custom footer",
        handler: async (_args, ctx) => {
          await run(controller.refresh(ctx, { force: true, warnForce: true }));
          ctx.ui.notify(
            Runtime.runSync(runtime)(controller.getStatus()) ||
              "OpenAI limits unavailable",
            "info",
          );
        },
      });
    });
  });
}

export function createCustomFooterExtension() {
  return function customFooterExtension(pi: ExtensionAPI) {
    runSyncEffect(
      customFooterExtensionEffect(pi).pipe(
        Effect.provide(CustomFooterRuntimeLayer),
      ),
    );
  };
}

function resolveFooterHomeEffect(): Effect.Effect<
  string | undefined,
  never,
  EnvironmentService
> {
  return Effect.gen(function* () {
    const environment = yield* EnvironmentService;
    return (
      (yield* environment.get("HOME")) ||
      (yield* environment.get("USERPROFILE"))
    );
  });
}

function renderFooter(
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  openAIStatus: string,
  home: string | undefined,
  width: number,
): string[] {
  const pwdLine = renderPwdLine(ctx, theme, footerData, home, width);
  const statsLine = renderStatsLine(
    ctx,
    pi,
    theme,
    footerData,
    openAIStatus,
    width,
  );
  const lines = [pwdLine, statsLine];

  const extensionStatuses = footerData.getExtensionStatuses();
  if (extensionStatuses.size > 0) {
    const statusLine = Array.from(extensionStatuses.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([, text]) => sanitizeStatusText(text))
      .join(" ");

    if (statusLine)
      lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
  }

  return lines;
}

function renderPwdLine(
  ctx: ExtensionContext,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  home: string | undefined,
  width: number,
): string {
  let pwd = formatCwdForFooter(ctx.sessionManager.getCwd(), home);

  const branch = footerData.getGitBranch();
  if (branch) pwd = `${pwd} (${branch})`;

  const sessionName = ctx.sessionManager.getSessionName();
  if (sessionName) pwd = `${pwd} • ${sessionName}`;

  return truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "..."));
}

function renderStatsLine(
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  theme: Theme,
  footerData: ReadonlyFooterDataProvider,
  openAIStatus: string,
  width: number,
): string {
  const entries = ctx.sessionManager.getEntries() as AssistantUsageEntry[];
  const usageSummary = summarizeAssistantUsage(entries);
  const usingSubscription = ctx.model
    ? ctx.modelRegistry.isUsingOAuth(ctx.model)
    : false;
  const contextDisplay = formatRemainingContextDisplay(
    ctx.getContextUsage(),
    ctx.model?.contextWindow,
    AUTO_COMPACT_ENABLED,
  );
  const statsParts = [
    ...buildUsageStatsParts(usageSummary, usingSubscription),
    contextDisplay.text,
  ];

  const inlineOpenAIStatus = formatInlineOpenAIStatus(openAIStatus);
  if (inlineOpenAIStatus) statsParts.push(inlineOpenAIStatus);

  const plainLine = buildStatsLine({
    width,
    statsParts,
    modelName: formatModelName(ctx, pi),
    providerName: ctx.model?.provider,
    availableProviderCount: footerData.getAvailableProviderCount(),
  });

  return styleStatsLine(theme, plainLine, contextDisplay);
}

function formatModelName(ctx: ExtensionContext, pi: ExtensionAPI): string {
  const modelName = ctx.model?.id || "no-model";
  if (!ctx.model?.reasoning) return modelName;

  const thinkingLevel = pi.getThinkingLevel();
  return thinkingLevel === "off"
    ? `${modelName} • thinking off`
    : `${modelName} • ${thinkingLevel}`;
}

function styleStatsLine(
  theme: Theme,
  plainLine: string,
  contextDisplay: RemainingContextDisplay,
): string {
  if (
    contextDisplay.severity !== "warning" &&
    contextDisplay.severity !== "error"
  ) {
    return theme.fg("dim", plainLine);
  }

  const contextStart = plainLine.indexOf(contextDisplay.text);
  if (contextStart < 0) return theme.fg("dim", plainLine);

  const before = plainLine.slice(0, contextStart);
  const after = plainLine.slice(contextStart + contextDisplay.text.length);
  const color = contextDisplay.severity;
  return (
    theme.fg("dim", before) +
    theme.fg(color, contextDisplay.text) +
    theme.fg("dim", after)
  );
}

function sanitizeStatusText(text: string): string {
  return text
    .replace(/[\r\n\t]/g, " ")
    .replace(/ +/g, " ")
    .trim();
}
