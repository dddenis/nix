import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { Clock, Duration, Effect, Fiber, Ref } from "effect";

import { errorToString } from "../shared/effect-runtime";
import { LoggerService } from "../shared/services";
import {
  formatRateLimitStatusEffect,
  type AccountRateLimitsResponse,
} from "./helpers";
import { JitterService, RateLimitClientService } from "./services";

export interface RefreshControllerConfig {
  refreshIntervalMs?: number;
  minRefreshGapMs?: number;
  backoffBaseMs?: number;
  backoffMaxMs?: number;
  warningDebounceMs?: number;
  sleepWakeThresholdMs?: number;
  wakeRefreshDelayMs?: number;
}

export interface RefreshController {
  refresh(
    ctx: ExtensionContext,
    options?: { force?: boolean; warnForce?: boolean },
  ): Effect.Effect<
    void,
    never,
    RateLimitClientService | JitterService | LoggerService | Clock.Clock
  >;
  startInterval(
    ctx: ExtensionContext,
  ): Effect.Effect<
    void,
    never,
    RateLimitClientService | JitterService | LoggerService | Clock.Clock
  >;
  shutdown(): Effect.Effect<void>;
  getStatus(): Effect.Effect<string>;
  setActiveTui(tui?: Pick<TUI, "requestRender">): Effect.Effect<void>;
  clearActiveTui(tui: Pick<TUI, "requestRender">): Effect.Effect<void>;
}

interface RefreshState {
  readonly lastIntervalTickAt: number;
  readonly lastRefreshStartedAt: number;
  readonly backoffUntil: number;
  readonly consecutiveFailures: number;
  readonly lastStatus: string;
  readonly lastSuccessfulStatus: string | undefined;
  readonly lastWarningAt: number;
  readonly lastWarningMessage: string | undefined;
  readonly activeTui: Pick<TUI, "requestRender"> | undefined;
}

const DEFAULT_REFRESH_INTERVAL_MS = 5 * 60_000;
const DEFAULT_MIN_REFRESH_GAP_MS = 30_000;
const DEFAULT_BACKOFF_BASE_MS = 60_000;
const DEFAULT_BACKOFF_MAX_MS = 15 * 60_000;
const DEFAULT_WARNING_DEBOUNCE_MS = 10 * 60_000;
const DEFAULT_WAKE_REFRESH_DELAY_MS = 45_000;

function initialState(): RefreshState {
  return {
    lastIntervalTickAt: 0,
    lastRefreshStartedAt: 0,
    backoffUntil: 0,
    consecutiveFailures: 0,
    lastStatus: "",
    lastSuccessfulStatus: undefined,
    lastWarningAt: Number.NEGATIVE_INFINITY,
    lastWarningMessage: undefined,
    activeTui: undefined,
  };
}

function staleStatus(state: RefreshState): string {
  return state.lastSuccessfulStatus
    ? `${state.lastSuccessfulStatus} stale`
    : "";
}

function interruptFiber(
  fiber: Fiber.Fiber<unknown, never> | undefined,
): Effect.Effect<void> {
  return fiber ? Fiber.interrupt(fiber).pipe(Effect.asVoid) : Effect.void;
}

export function makeRefreshController(
  config: RefreshControllerConfig = {},
): Effect.Effect<
  RefreshController,
  never,
  RateLimitClientService | JitterService | LoggerService | Clock.Clock
> {
  const refreshIntervalMs =
    config.refreshIntervalMs ?? DEFAULT_REFRESH_INTERVAL_MS;
  const minRefreshGapMs = config.minRefreshGapMs ?? DEFAULT_MIN_REFRESH_GAP_MS;
  const backoffBaseMs = config.backoffBaseMs ?? DEFAULT_BACKOFF_BASE_MS;
  const backoffMaxMs = config.backoffMaxMs ?? DEFAULT_BACKOFF_MAX_MS;
  const warningDebounceMs =
    config.warningDebounceMs ?? DEFAULT_WARNING_DEBOUNCE_MS;
  const sleepWakeThresholdMs =
    config.sleepWakeThresholdMs ?? refreshIntervalMs + 60_000;
  const wakeRefreshDelayMs =
    config.wakeRefreshDelayMs ?? DEFAULT_WAKE_REFRESH_DELAY_MS;

  return Effect.gen(function* () {
    const stateRef = yield* Ref.make(initialState());
    let intervalFiber: Fiber.RuntimeFiber<unknown, never> | undefined;
    let wakeDelayFiber: Fiber.RuntimeFiber<void, never> | undefined;
    let refreshFiber: Fiber.RuntimeFiber<void, never> | undefined;

    const requestRender = (
      tui: Pick<TUI, "requestRender"> | undefined,
    ): Effect.Effect<void> =>
      tui ? Effect.sync(() => tui.requestRender()) : Effect.void;

    const setInlineStatus = (status: string): Effect.Effect<void> =>
      Ref.modify(
        stateRef,
        (current) =>
          [current.activeTui, { ...current, lastStatus: status }] as const,
      ).pipe(Effect.flatMap(requestRender));

    const applySuccess = (
      response: AccountRateLimitsResponse,
    ): Effect.Effect<void, never, Clock.Clock> =>
      Effect.gen(function* () {
        const formatted = yield* formatRateLimitStatusEffect(response);
        const tui = yield* Ref.modify(stateRef, (current) => {
          const lastSuccessfulStatus =
            formatted === "OpenAI limits unavailable"
              ? current.lastSuccessfulStatus
              : formatted;
          return [
            current.activeTui,
            {
              ...current,
              lastStatus: formatted,
              lastSuccessfulStatus,
              consecutiveFailures: 0,
              backoffUntil: 0,
            },
          ] as const;
        });
        yield* requestRender(tui);
      });

    const applyFailure = (
      error: Error,
      warnForce: boolean,
    ): Effect.Effect<void, never, JitterService | LoggerService> =>
      Effect.gen(function* () {
        const jitter = yield* JitterService;
        const logger = yield* LoggerService;
        const multiplier = yield* jitter.nextMultiplier();
        const currentTime = yield* Clock.currentTimeMillis;
        const message = errorToString(error);
        const update = yield* Ref.modify(stateRef, (current) => {
          const backoffMs = Math.min(
            backoffMaxMs,
            Math.round(
              backoffBaseMs * 2 ** current.consecutiveFailures * multiplier,
            ),
          );
          const nextStatus = staleStatus(current);
          const shouldWarn =
            warnForce ||
            message !== current.lastWarningMessage ||
            currentTime - current.lastWarningAt >= warningDebounceMs;
          return [
            { tui: current.activeTui, shouldWarn, message },
            {
              ...current,
              lastStatus: nextStatus,
              consecutiveFailures: current.consecutiveFailures + 1,
              backoffUntil: currentTime + backoffMs,
              lastWarningAt: shouldWarn ? currentTime : current.lastWarningAt,
              lastWarningMessage: shouldWarn
                ? message
                : current.lastWarningMessage,
            },
          ] as const;
        });

        yield* requestRender(update.tui);
        if (update.shouldWarn)
          yield* logger.warn(`[custom-footer] ${update.message}`);
      });

    const runRefreshAttempt = (
      warnForce: boolean,
    ): Effect.Effect<
      void,
      never,
      RateLimitClientService | JitterService | LoggerService | Clock.Clock
    > =>
      Effect.gen(function* () {
        const client = yield* RateLimitClientService;
        yield* client.read().pipe(
          Effect.flatMap((response) => applySuccess(response)),
          Effect.catchAll((error) => applyFailure(error, warnForce)),
        );
      });

    const joinRefreshFiber = (): Effect.Effect<void> =>
      refreshFiber ? Fiber.join(refreshFiber) : Effect.void;

    const refresh: RefreshController["refresh"] = (ctx, options = {}) =>
      Effect.gen(function* () {
        if (!ctx.hasUI) return;

        const currentTime = yield* Clock.currentTimeMillis;
        const current = yield* Ref.get(stateRef);
        if (
          !options.force &&
          currentTime - current.lastRefreshStartedAt < minRefreshGapMs
        ) {
          yield* joinRefreshFiber();
          return;
        }

        if (!options.warnForce && currentTime < current.backoffUntil) {
          yield* setInlineStatus(staleStatus(current));
          yield* joinRefreshFiber();
          return;
        }

        if (refreshFiber) {
          yield* Fiber.join(refreshFiber);
          return;
        }

        yield* Ref.update(stateRef, (state) => ({
          ...state,
          lastRefreshStartedAt: currentTime,
        }));
        const fiber = yield* Effect.forkDaemon(
          runRefreshAttempt(Boolean(options.warnForce)).pipe(
            Effect.ensuring(
              Effect.sync(() => {
                refreshFiber = undefined;
              }),
            ),
          ),
        );
        refreshFiber = fiber;
        yield* Fiber.join(fiber);
      });

    const scheduleRefreshAfterWake = (
      ctx: ExtensionContext,
    ): Effect.Effect<
      void,
      never,
      RateLimitClientService | JitterService | LoggerService | Clock.Clock
    > =>
      Effect.gen(function* () {
        if (wakeDelayFiber) return;

        const fiber = yield* Effect.forkDaemon(
          Clock.sleep(Duration.millis(wakeRefreshDelayMs)).pipe(
            Effect.zipRight(
              Effect.sync(() => {
                wakeDelayFiber = undefined;
              }),
            ),
            Effect.zipRight(refresh(ctx)),
          ),
        );
        wakeDelayFiber = fiber;
      });

    const onIntervalTick = (
      ctx: ExtensionContext,
    ): Effect.Effect<
      void,
      never,
      RateLimitClientService | JitterService | LoggerService | Clock.Clock
    > =>
      Effect.gen(function* () {
        const currentTime = yield* Clock.currentTimeMillis;
        const action = yield* Ref.modify(stateRef, (current) => {
          const intervalGapMs = currentTime - current.lastIntervalTickAt;
          const nextBase = { ...current, lastIntervalTickAt: currentTime };

          if (intervalGapMs > sleepWakeThresholdMs) {
            return [
              {
                _tag: "wake",
                tui: current.activeTui,
                status: staleStatus(current),
              } as const,
              { ...nextBase, lastStatus: staleStatus(current) },
            ];
          }

          return [{ _tag: "refresh" } as const, nextBase];
        });

        if (action._tag === "wake") {
          yield* requestRender(action.tui);
          yield* scheduleRefreshAfterWake(ctx);
          return;
        }

        yield* refresh(ctx);
      });

    const startInterval: RefreshController["startInterval"] = (ctx) =>
      Effect.gen(function* () {
        const currentIntervalFiber = intervalFiber;
        const currentWakeDelayFiber = wakeDelayFiber;
        intervalFiber = undefined;
        wakeDelayFiber = undefined;
        yield* interruptFiber(currentIntervalFiber);
        yield* interruptFiber(currentWakeDelayFiber);

        if (!ctx.hasUI) return;

        const currentTime = yield* Clock.currentTimeMillis;
        yield* Ref.update(stateRef, (current) => ({
          ...current,
          lastIntervalTickAt: currentTime,
        }));
        const fiber = yield* Effect.forkDaemon(
          Clock.sleep(Duration.millis(refreshIntervalMs)).pipe(
            Effect.zipRight(onIntervalTick(ctx)),
            Effect.forever,
          ),
        );
        intervalFiber = fiber;
      });

    const shutdown = (): Effect.Effect<void> =>
      Effect.gen(function* () {
        const currentIntervalFiber = intervalFiber;
        const currentWakeDelayFiber = wakeDelayFiber;
        const currentRefreshFiber = refreshFiber;
        intervalFiber = undefined;
        wakeDelayFiber = undefined;
        refreshFiber = undefined;
        yield* interruptFiber(currentIntervalFiber);
        yield* interruptFiber(currentWakeDelayFiber);
        yield* interruptFiber(currentRefreshFiber);
        yield* Ref.update(stateRef, (current) => ({
          ...current,
          activeTui: undefined,
        }));
      });

    return {
      refresh,
      startInterval,
      shutdown,
      getStatus: () =>
        Ref.get(stateRef).pipe(Effect.map((state) => state.lastStatus)),
      setActiveTui: (tui) =>
        Ref.update(stateRef, (current) => ({ ...current, activeTui: tui })),
      clearActiveTui: (tui) =>
        Ref.update(stateRef, (current) =>
          current.activeTui === tui
            ? { ...current, activeTui: undefined }
            : current,
        ),
    };
  });
}
