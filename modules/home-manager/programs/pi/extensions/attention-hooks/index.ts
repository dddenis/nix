import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn as defaultSpawn } from "node:child_process";
import { existsSync as defaultExistsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const SOUND_FILE_NAME = "vittemacop-alert-notification-pop-cartoon-bubble-pop-pop-up-478078.mp3";

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

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (event) => {
    if (!shouldPlayCompletionSound(event.messages)) return;

    playCompletionSound();
  });
}
