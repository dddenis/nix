import type { ChildProcess } from "node:child_process";
import { spawn as defaultSpawn } from "node:child_process";
import { existsSync as defaultExistsSync } from "node:fs";
import {
  readFile as defaultReadFile,
  stat as defaultStat,
} from "node:fs/promises";
import { homedir } from "node:os";
import { Context, Effect, Layer } from "effect";

type EnvironmentServiceShape = {
  readonly get: (name: string) => Effect.Effect<string | undefined>;
  readonly snapshot: () => Effect.Effect<NodeJS.ProcessEnv>;
};

type HomeDirectoryServiceShape = {
  readonly get: () => Effect.Effect<string>;
};

type FileSystemServiceShape = {
  readonly exists: (path: string) => Effect.Effect<boolean>;
  readonly readTextFile: (path: string) => Effect.Effect<string, Error>;
  readonly statMtimeMs: (path: string) => Effect.Effect<number, Error>;
};

export type SpawnedProcess = Pick<
  ChildProcess,
  | "killed"
  | "kill"
  | "on"
  | "removeAllListeners"
  | "stdin"
  | "stdout"
  | "stderr"
  | "unref"
>;

export type SpawnOptions = Parameters<typeof defaultSpawn>[2];

export type ProcessServiceShape = {
  readonly spawn: (
    command: string,
    args: string[],
    options: SpawnOptions,
  ) => Effect.Effect<SpawnedProcess, Error>;
};

type LoggerServiceShape = {
  readonly warn: (message: string) => Effect.Effect<void>;
};

export class EnvironmentService extends Context.Tag(
  "ddd-pi-extensions/EnvironmentService",
)<EnvironmentService, EnvironmentServiceShape>() {}
export class HomeDirectoryService extends Context.Tag(
  "ddd-pi-extensions/HomeDirectoryService",
)<HomeDirectoryService, HomeDirectoryServiceShape>() {}
export class FileSystemService extends Context.Tag(
  "ddd-pi-extensions/FileSystemService",
)<FileSystemService, FileSystemServiceShape>() {}
export class ProcessService extends Context.Tag(
  "ddd-pi-extensions/ProcessService",
)<ProcessService, ProcessServiceShape>() {}
export class LoggerService extends Context.Tag(
  "ddd-pi-extensions/LoggerService",
)<LoggerService, LoggerServiceShape>() {}

export const EnvironmentLiveLayer = Layer.succeed(EnvironmentService, {
  get: (name) => Effect.sync(() => process.env[name]),
  snapshot: () => Effect.sync(() => ({ ...process.env })),
});

export const HomeDirectoryLiveLayer = Layer.succeed(HomeDirectoryService, {
  get: () => Effect.sync(() => homedir()),
});

export const FileSystemLiveLayer = Layer.succeed(FileSystemService, {
  exists: (path) => Effect.sync(() => defaultExistsSync(path)),
  readTextFile: (path) =>
    Effect.tryPromise({
      try: () => defaultReadFile(path, "utf8"),
      catch: toError,
    }),
  statMtimeMs: (path) =>
    Effect.tryPromise({
      try: () => defaultStat(path).then((file) => file.mtimeMs),
      catch: toError,
    }),
});

export const ProcessLiveLayer = Layer.succeed(ProcessService, {
  spawn: (command, args, options) =>
    Effect.try({
      try: () => defaultSpawn(command, args, options),
      catch: toError,
    }),
});

export const LoggerLiveLayer = Layer.succeed(LoggerService, {
  warn: (message) => Effect.sync(() => console.warn(message)),
});

export const SharedLiveLayer = Layer.mergeAll(
  EnvironmentLiveLayer,
  HomeDirectoryLiveLayer,
  FileSystemLiveLayer,
  ProcessLiveLayer,
  LoggerLiveLayer,
);

function toError(error: unknown): Error {
  return error instanceof Error ? error : new Error(String(error));
}
