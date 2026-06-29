import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn as defaultSpawn } from "node:child_process";
import { existsSync as defaultExistsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const SOUND_FILE_NAME = "vittemacop-alert-notification-pop-cartoon-bubble-pop-pop-up-478078.mp3";

const CONTROL_EVENT_UNSUBSCRIBE_KEY = "__attention_hooks_control_event_unsubscribe__";

type SpawnedProcess = {
  on?: (event: "error", listener: (error: Error) => void) => unknown;
  unref?: () => void;
};

type SpawnSoundProcess = (
  command: string,
  args: string[],
  options: { detached: true; stdio: "ignore" },
) => SpawnedProcess;

type SoundDecisionMessage = {
  role?: string;
  stopReason?: string;
};

export type PlayCompletionSoundOptions = {
  homeDir?: string;
  existsSync?: (path: string) => boolean;
  spawn?: SpawnSoundProcess;
};

type AttentionHooksEnvironment = {
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

export function getCompletionSoundPath(homeDir = homedir()): string {
  return join(homeDir, ".pi", "agent", SOUND_FILE_NAME);
}

export function shouldPlayCompletionSound(messages: readonly SoundDecisionMessage[]): boolean {
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index];
    if (message?.role === "assistant") return message.stopReason !== "aborted";
  }

  return true;
}

export function playCompletionSound(options: PlayCompletionSoundOptions = {}): void {
  const soundPath = getCompletionSoundPath(options.homeDir ?? homedir());
  const existsSync = options.existsSync ?? defaultExistsSync;

  if (!existsSync(soundPath)) return;

  const spawn = options.spawn ?? (defaultSpawn as SpawnSoundProcess);

  try {
    const child = spawn("afplay", [soundPath], { detached: true, stdio: "ignore" });
    child.on?.("error", () => undefined);
    child.unref?.();
  } catch {
    // Completion sounds are best-effort only.
  }
}

function isSubagentChild(env: AttentionHooksEnvironment): boolean {
  return env.PI_SUBAGENT_CHILD === "1";
}

export function shouldPlayAgentEndSound(
  messages: readonly SoundDecisionMessage[],
  env: AttentionHooksEnvironment = process.env,
): boolean {
  if (isSubagentChild(env)) return false;

  return shouldPlayCompletionSound(messages);
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

export function registerAttentionHooks(
  pi: Pick<ExtensionAPI, "on" | "events">,
  options: RegisterAttentionHooksOptions = {},
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

export default function (pi: ExtensionAPI) {
  registerAttentionHooks(pi);
}
