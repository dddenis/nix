import { Context, Effect, Layer, Ref, Runtime } from "effect";
import {
  EnvironmentService,
  FileSystemService,
  HomeDirectoryService,
  LoggerService,
  ProcessService,
  type SpawnOptions,
  type SpawnedProcess,
} from "./services";
import { TuiPrimitivesService, type TuiInputLike } from "./tui-primitives";

type FileFixture = { readonly content: string; readonly mtimeMs: number };
type SpawnCall = {
  readonly command: string;
  readonly args: readonly string[];
  readonly options: SpawnOptions;
};

interface SharedServicesTestState {
  readonly env: Readonly<Record<string, string | undefined>>;
  readonly homeDir: string;
  readonly existingPaths: ReadonlySet<string>;
  readonly files: ReadonlyMap<string, FileFixture>;
  readonly spawnResults: readonly SpawnedProcess[];
  readonly spawnFailure: Error | undefined;
  readonly spawnCalls: readonly SpawnCall[];
  readonly warnings: readonly string[];
}

interface SharedServicesTestShape {
  readonly setEnv: (
    name: string,
    value: string | undefined,
  ) => Effect.Effect<void>;
  readonly setHomeDir: (path: string) => Effect.Effect<void>;
  readonly addExistingPath: (path: string) => Effect.Effect<void>;
  readonly putFile: (path: string, file: FileFixture) => Effect.Effect<void>;
  readonly enqueueSpawnResult: (child: SpawnedProcess) => Effect.Effect<void>;
  readonly setSpawnFailure: (error: Error | undefined) => Effect.Effect<void>;
  readonly getState: Effect.Effect<SharedServicesTestState>;
  readonly resetCalls: Effect.Effect<void>;
  readonly reset: Effect.Effect<void>;
}

const initialSharedState = (): SharedServicesTestState => ({
  env: {},
  homeDir: "/tmp/home",
  existingPaths: new Set(),
  files: new Map(),
  spawnResults: [],
  spawnFailure: undefined,
  spawnCalls: [],
  warnings: [],
});

export class SharedServicesTest extends Context.Tag(
  "ddd-pi-extensions/SharedServicesTest",
)<SharedServicesTest, SharedServicesTestShape>() {
  static readonly layer = Layer.unwrapEffect(
    Effect.gen(function* () {
      const state = yield* Ref.make(initialSharedState());
      const snapshot = Ref.get(state).pipe(Effect.map(copySharedState));

      const controls: SharedServicesTestShape = {
        setEnv: (name, value) =>
          Ref.update(state, (current) => ({
            ...current,
            env: { ...current.env, [name]: value },
          })),
        setHomeDir: (homeDir) =>
          Ref.update(state, (current) => ({ ...current, homeDir })),
        addExistingPath: (path) =>
          Ref.update(state, (current) => ({
            ...current,
            existingPaths: new Set([...current.existingPaths, path]),
          })),
        putFile: (path, file) =>
          Ref.update(state, (current) => ({
            ...current,
            files: new Map(current.files).set(path, file),
          })),
        enqueueSpawnResult: (child) =>
          Ref.update(state, (current) => ({
            ...current,
            spawnResults: [...current.spawnResults, child],
          })),
        setSpawnFailure: (error) =>
          Ref.update(state, (current) => ({ ...current, spawnFailure: error })),
        getState: snapshot,
        resetCalls: Ref.update(state, (current) => ({
          ...current,
          spawnCalls: [],
          warnings: [],
        })),
        reset: Ref.set(state, initialSharedState()),
      };

      return Layer.mergeAll(
        Layer.succeed(SharedServicesTest, controls),
        Layer.succeed(EnvironmentService, {
          get: (name) =>
            Ref.get(state).pipe(Effect.map((current) => current.env[name])),
          snapshot: () =>
            Ref.get(state).pipe(Effect.map((current) => ({ ...current.env }))),
        }),
        Layer.succeed(HomeDirectoryService, {
          get: () =>
            Ref.get(state).pipe(Effect.map((current) => current.homeDir)),
        }),
        Layer.succeed(FileSystemService, {
          exists: (path) =>
            Ref.get(state).pipe(
              Effect.map(
                (current) =>
                  current.existingPaths.has(path) || current.files.has(path),
              ),
            ),
          readTextFile: (path) =>
            Ref.get(state).pipe(
              Effect.flatMap((current) =>
                current.files.has(path)
                  ? Effect.succeed(current.files.get(path)!.content)
                  : Effect.dieMessage(`Missing test file fixture: ${path}`),
              ),
            ),
          statMtimeMs: (path) =>
            Ref.get(state).pipe(
              Effect.flatMap((current) =>
                current.files.has(path)
                  ? Effect.succeed(current.files.get(path)!.mtimeMs)
                  : Effect.dieMessage(`Missing test file fixture: ${path}`),
              ),
            ),
        }),
        Layer.succeed(ProcessService, {
          spawn: (command, args, options) =>
            Ref.modify(state, (current) => {
              const call = { command, args: [...args], options };
              const withCall = {
                ...current,
                spawnCalls: [...current.spawnCalls, call],
              };
              if (current.spawnFailure)
                return [Effect.fail(current.spawnFailure), withCall];
              const [child, ...rest] = current.spawnResults;
              if (!child)
                return [
                  Effect.dieMessage(`Missing spawn fixture for ${command}`),
                  withCall,
                ];
              return [
                Effect.succeed(child),
                { ...withCall, spawnResults: rest },
              ];
            }).pipe(Effect.flatten),
        }),
        Layer.succeed(LoggerService, {
          warn: (message) =>
            Ref.update(state, (current) => ({
              ...current,
              warnings: [...current.warnings, message],
            })),
        }),
      );
    }),
  );
}

interface TuiPrimitiveInputSnapshot {
  readonly id: number;
  readonly value: string;
  readonly focused: boolean;
  readonly handleInputCalls: readonly string[];
}

interface TuiPrimitivesTestState {
  readonly createdInputs: readonly TuiPrimitiveInputSnapshot[];
}

interface TuiPrimitivesTestShape {
  readonly getState: Effect.Effect<TuiPrimitivesTestState>;
  readonly resetCalls: Effect.Effect<void>;
  readonly reset: Effect.Effect<void>;
}

export class TuiPrimitivesTest extends Context.Tag(
  "ddd-pi-extensions/TuiPrimitivesTest",
)<TuiPrimitivesTest, TuiPrimitivesTestShape>() {
  static readonly layer = Layer.unwrapEffect(
    Effect.gen(function* () {
      const runtime = yield* Effect.runtime<never>();
      const state = yield* Ref.make<TuiPrimitivesTestState>({
        createdInputs: [],
      });
      const readState = (): TuiPrimitivesTestState =>
        Runtime.runSync(runtime)(Ref.get(state));
      const writeState = (
        update: (current: TuiPrimitivesTestState) => TuiPrimitivesTestState,
      ): void => {
        Runtime.runSync(runtime)(Ref.update(state, update));
      };

      const controls: TuiPrimitivesTestShape = {
        getState: Ref.get(state).pipe(
          Effect.map((current) => ({
            createdInputs: current.createdInputs.map((input) => ({
              ...input,
              handleInputCalls: [...input.handleInputCalls],
            })),
          })),
        ),
        resetCalls: Ref.update(state, (current) => ({
          createdInputs: current.createdInputs.map((input) => ({
            ...input,
            handleInputCalls: [],
          })),
        })),
        reset: Ref.set(state, { createdInputs: [] }),
      };

      const makeInput = (id: number): TuiInputLike => ({
        get focused() {
          return (
            readState().createdInputs.find((input) => input.id === id)
              ?.focused ?? false
          );
        },
        set focused(value: boolean) {
          writeState((current) => ({
            ...current,
            createdInputs: current.createdInputs.map((input) =>
              input.id === id ? { ...input, focused: value } : input,
            ),
          }));
        },
        setValue(value) {
          writeState((current) => ({
            ...current,
            createdInputs: current.createdInputs.map((input) =>
              input.id === id ? { ...input, value } : input,
            ),
          }));
        },
        getValue() {
          return (
            readState().createdInputs.find((input) => input.id === id)?.value ??
            ""
          );
        },
        handleInput(data) {
          writeState((current) => ({
            ...current,
            createdInputs: current.createdInputs.map((input) =>
              input.id === id
                ? {
                    ...input,
                    value: input.value + data,
                    handleInputCalls: [...input.handleInputCalls, data],
                  }
                : input,
            ),
          }));
        },
        render(width) {
          return [truncateForTest(this.getValue(), width, "")];
        },
        invalidate() {},
      });

      return Layer.mergeAll(
        Layer.succeed(TuiPrimitivesTest, controls),
        Layer.succeed(TuiPrimitivesService, {
          createInput: () =>
            Ref.modify(state, (current) => {
              const id = current.createdInputs.length + 1;
              const input = {
                id,
                value: "",
                focused: false,
                handleInputCalls: [],
              };
              return [
                makeInput(id),
                { createdInputs: [...current.createdInputs, input] },
              ];
            }),
          key: {
            escape: "\x1b",
            up: "\x1b[A",
            down: "\x1b[B",
            enter: "\r",
            return: "\n",
            ctrl: (key) => `ctrl+${key}`,
          },
          matchesKey: (data, key) => data === key,
          truncateToWidth: truncateForTest,
          visibleWidth: visibleWidthForTest,
        }),
      );
    }),
  );
}

function copySharedState(
  state: SharedServicesTestState,
): SharedServicesTestState {
  return {
    ...state,
    env: { ...state.env },
    existingPaths: new Set(state.existingPaths),
    files: new Map(state.files),
    spawnResults: [...state.spawnResults],
    spawnCalls: state.spawnCalls.map((call) => ({
      ...call,
      args: [...call.args],
    })),
    warnings: [...state.warnings],
  };
}

function visibleWidthForTest(value: string): number {
  return [...value.replace(/\x1b\[[0-9;]*m/g, "")].length;
}

function truncateForTest(value: string, width: number, ellipsis = "…"): string {
  if (visibleWidthForTest(value) <= width) return value;
  if (width <= visibleWidthForTest(ellipsis))
    return [...ellipsis].slice(0, Math.max(0, width)).join("");
  return (
    [...value].slice(0, width - visibleWidthForTest(ellipsis)).join("") +
    ellipsis
  );
}
