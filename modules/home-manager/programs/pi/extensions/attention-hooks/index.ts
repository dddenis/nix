import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn as defaultSpawn } from "node:child_process";
import { existsSync as defaultExistsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Effect, Option, Runtime } from "effect";

import { runSyncEffect } from "../shared/effect-runtime";
import {
  EnvironmentService,
  FileSystemService,
  HomeDirectoryService,
  ProcessService,
  SharedLiveLayer,
} from "../shared/services";

export const SOUND_FILE_NAME =
  "vittemacop-alert-notification-pop-cartoon-bubble-pop-pop-up-478078.mp3";

const CONTROL_EVENT_UNSUBSCRIBE_KEY =
  "__attention_hooks_control_event_unsubscribe__";

type SpawnedProcess = {
  on?: (event: "error", listener: (error: Error) => void) => unknown;
  unref?: () => void;
};

type SpawnSoundProcess = (
  command: string,
  args: string[],
  options: { detached: true; stdio: "ignore" },
) => SpawnedProcess;

export type SoundDecisionMessage = {
  role?: string;
  stopReason?: string;
};

export type PlayCompletionSoundOptions = {
  homeDir?: string;
  existsSync?: (path: string) => boolean;
  spawn?: SpawnSoundProcess;
};

export type AttentionHooksEnvironment = {
  PI_SUBAGENT_CHILD?: string;
};

export type RegisterAttentionHooksOptions = {
  env?: AttentionHooksEnvironment;
  playSound?: () => void;
};

type SubagentControlPayload = {
  event?: {
    type?: string;
  };
};

type Unsubscribe = () => void;

type AttentionHooksServices =
  | EnvironmentService
  | HomeDirectoryService
  | FileSystemService
  | ProcessService;

export function getCompletionSoundPathEffect(): Effect.Effect<
  string,
  never,
  HomeDirectoryService
> {
  return Effect.gen(function* () {
    const home = yield* HomeDirectoryService;
    return join(yield* home.get(), ".pi", "agent", SOUND_FILE_NAME);
  });
}

export function getCompletionSoundPath(homeDir = homedir()): string {
  return join(homeDir, ".pi", "agent", SOUND_FILE_NAME);
}

export function shouldPlayCompletionSoundEffect(
  messages: readonly SoundDecisionMessage[],
): Effect.Effect<boolean> {
  return Effect.sync(() => {
    const lastAssistant = Option.fromNullable(
      [...messages].reverse().find((message) => message?.role === "assistant"),
    );
    return Option.match(lastAssistant, {
      onNone: () => true,
      onSome: (message) => message.stopReason !== "aborted",
    });
  });
}

export function shouldPlayCompletionSound(
  messages: readonly SoundDecisionMessage[],
): boolean {
  return runSyncEffect(shouldPlayCompletionSoundEffect(messages));
}

function playCompletionSoundWithOptions(
  options: PlayCompletionSoundOptions,
): void {
  const soundPath = getCompletionSoundPath(options.homeDir ?? homedir());
  const existsSync = options.existsSync ?? defaultExistsSync;

  if (!existsSync(soundPath)) return;

  const spawn = options.spawn ?? (defaultSpawn as SpawnSoundProcess);

  try {
    const child = spawn("afplay", [soundPath], {
      detached: true,
      stdio: "ignore",
    });
    child.on?.("error", () => undefined);
    child.unref?.();
  } catch {
    // Completion sounds are best-effort only.
  }
}

export function playCompletionSoundEffect(): Effect.Effect<
  void,
  never,
  HomeDirectoryService | FileSystemService | ProcessService
> {
  return Effect.gen(function* () {
    const soundPath = yield* getCompletionSoundPathEffect();
    const fs = yield* FileSystemService;
    if (!(yield* fs.exists(soundPath))) return;

    const processes = yield* ProcessService;
    const child = yield* processes
      .spawn("afplay", [soundPath], { detached: true, stdio: "ignore" })
      .pipe(Effect.catchAll(() => Effect.succeed(undefined)));

    if (!child) return;

    yield* Effect.try({
      try: () => {
        child.on?.("error", () => undefined);
        child.unref?.();
      },
      catch: () => undefined,
    }).pipe(Effect.catchAll(() => Effect.void));
  }).pipe(Effect.catchAll(() => Effect.void));
}

export function playCompletionSound(
  options?: PlayCompletionSoundOptions,
): void {
  if (options !== undefined) {
    playCompletionSoundWithOptions(options);
    return;
  }

  runSyncEffect(
    playCompletionSoundEffect().pipe(Effect.provide(SharedLiveLayer)),
  );
}

function isSubagentChild(env: AttentionHooksEnvironment): boolean {
  return env.PI_SUBAGENT_CHILD === "1";
}

function isSubagentChildEffect(): Effect.Effect<
  boolean,
  never,
  EnvironmentService
> {
  return Effect.gen(function* () {
    const env = yield* EnvironmentService;
    return (yield* env.get("PI_SUBAGENT_CHILD")) === "1";
  });
}

export function shouldPlayAgentEndSoundEffect(
  messages: readonly SoundDecisionMessage[],
): Effect.Effect<boolean, never, EnvironmentService> {
  return Effect.gen(function* () {
    if (yield* isSubagentChildEffect()) return false;
    return yield* shouldPlayCompletionSoundEffect(messages);
  });
}

export function shouldPlayAgentEndSound(
  messages: readonly SoundDecisionMessage[],
  env: AttentionHooksEnvironment = process.env,
): boolean {
  if (isSubagentChild(env)) return false;

  return shouldPlayCompletionSound(messages);
}

export function shouldPlaySubagentControlSoundEffect(
  payload: unknown,
): Effect.Effect<boolean, never, EnvironmentService> {
  return Effect.gen(function* () {
    if (yield* isSubagentChildEffect()) return false;

    const controlPayload = payload as SubagentControlPayload | undefined;
    return controlPayload?.event?.type === "needs_attention";
  });
}

export function shouldPlaySubagentControlSound(
  payload: unknown,
  env: AttentionHooksEnvironment = process.env,
): boolean {
  if (isSubagentChild(env)) return false;

  const controlPayload = payload as SubagentControlPayload | undefined;

  return controlPayload?.event?.type === "needs_attention";
}

function replaceControlEventSubscription(unsubscribe: Unsubscribe): void {
  const globalStore = globalThis as Record<string, unknown>;
  const previousUnsubscribe = globalStore[CONTROL_EVENT_UNSUBSCRIBE_KEY];

  if (typeof previousUnsubscribe === "function") {
    try {
      previousUnsubscribe();
    } catch {
      // Best effort cleanup for stale handlers from an older reload.
    }
  }

  globalStore[CONTROL_EVENT_UNSUBSCRIBE_KEY] = unsubscribe;
}

function registerAttentionHooksWithOptions(
  pi: Pick<ExtensionAPI, "on" | "events">,
  options: RegisterAttentionHooksOptions,
): void {
  const env = options.env ?? process.env;
  const playSound = options.playSound ?? (() => playCompletionSound());

  pi.on("agent_end", async (event) => {
    if (!shouldPlayAgentEndSound(event.messages, env)) return;

    playSound();
  });

  replaceControlEventSubscription(
    pi.events.on("subagent:control-event", (payload) => {
      if (!shouldPlaySubagentControlSound(payload, env)) return;

      playSound();
    }),
  );
}

export function registerAttentionHooksEffect(
  pi: Pick<ExtensionAPI, "on" | "events">,
): Effect.Effect<void, never, AttentionHooksServices> {
  return Effect.gen(function* () {
    const runtime = yield* Effect.runtime<AttentionHooksServices>();
    const runInCapturedContext = <A, E>(
      program: Effect.Effect<A, E, AttentionHooksServices>,
    ) =>
      Runtime.runPromise(runtime)(
        program.pipe(Effect.catchAll(() => Effect.void)),
      ) as Promise<void>;

    yield* Effect.sync(() => {
      pi.on("agent_end", async (event) => {
        await runInCapturedContext(
          Effect.gen(function* () {
            if (!(yield* shouldPlayAgentEndSoundEffect(event.messages))) return;
            yield* playCompletionSoundEffect();
          }),
        );
      });

      replaceControlEventSubscription(
        pi.events.on("subagent:control-event", (payload) => {
          void runInCapturedContext(
            Effect.gen(function* () {
              if (!(yield* shouldPlaySubagentControlSoundEffect(payload)))
                return;
              yield* playCompletionSoundEffect();
            }),
          );
        }),
      );
    });
  });
}

export function registerAttentionHooks(
  pi: Pick<ExtensionAPI, "on" | "events">,
  options?: RegisterAttentionHooksOptions,
): void {
  if (options !== undefined) {
    registerAttentionHooksWithOptions(pi, options);
    return;
  }

  runSyncEffect(
    registerAttentionHooksEffect(pi).pipe(Effect.provide(SharedLiveLayer)),
  );
}

export default function (pi: ExtensionAPI) {
  registerAttentionHooks(pi);
}
