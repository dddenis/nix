import { describe, expect, test } from "bun:test";

import { SOUND_FILE_NAME, getCompletionSoundPath, playCompletionSound } from "./index";

describe("attention hooks", () => {
  test("uses only the Pi agent sound file path", () => {
    const homeDir = "/Users/ddd";

    expect(getCompletionSoundPath(homeDir)).toBe(`/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`);
  });

  test("does not spawn afplay when the Pi agent sound file is missing", () => {
    const homeDir = "/Users/ddd";
    const checkedPaths: string[] = [];
    const spawnCalls: string[] = [];

    playCompletionSound({
      homeDir,
      existsSync: (path) => {
        checkedPaths.push(path);
        return path.includes("/.claude/") || path.includes("/.codex/");
      },
      spawn: (command) => {
        spawnCalls.push(command);
        return {};
      },
    });

    expect(checkedPaths).toEqual([`/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`]);
    expect(spawnCalls).toEqual([]);
  });

  test("plays the existing Pi agent sound without blocking", () => {
    const homeDir = "/Users/ddd";
    const soundPath = `/Users/ddd/.pi/agent/${SOUND_FILE_NAME}`;
    let unrefCalled = false;
    let errorHandlerRegistered = false;
    let spawnCall: unknown;

    playCompletionSound({
      homeDir,
      existsSync: (path) => path === soundPath,
      spawn: (command, args, options) => {
        spawnCall = { command, args, options };
        return {
          on(event: string) {
            if (event === "error") errorHandlerRegistered = true;
            return this;
          },
          unref() {
            unrefCalled = true;
          },
        };
      },
    });

    expect(spawnCall).toEqual({
      command: "afplay",
      args: [soundPath],
      options: { detached: true, stdio: "ignore" },
    });
    expect(errorHandlerRegistered).toBe(true);
    expect(unrefCalled).toBe(true);
  });

  test("silently ignores afplay spawn failures", () => {
    expect(() =>
      playCompletionSound({
        homeDir: "/Users/ddd",
        existsSync: () => true,
        spawn: () => {
          throw new Error("afplay unavailable");
        },
      }),
    ).not.toThrow();
  });
});
