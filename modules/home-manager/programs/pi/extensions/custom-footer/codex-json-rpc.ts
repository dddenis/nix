import { join } from "node:path";
import { createInterface } from "node:readline";
import { Clock, Duration, Effect, Either, Option, Schema } from "effect";

import { errorToString } from "../shared/effect-runtime";
import {
  EnvironmentService,
  FileSystemService,
  HomeDirectoryService,
  ProcessService,
  SharedLiveLayer,
} from "../shared/services";
import {
  parseRateLimitsJsonRpcLineEffect,
  type AccountRateLimitsResponse,
} from "./helpers";

export interface CodexJsonRpcConfig {
  timeoutMs?: number;
}

const JsonRpcResultLineSchema = Schema.parseJson(
  Schema.Struct({
    id: Schema.Number,
    result: Schema.optional(Schema.Unknown),
  }),
);

const JsonRpcErrorLineSchema = Schema.parseJson(
  Schema.Struct({
    id: Schema.Number,
    error: Schema.optional(
      Schema.Struct({
        message: Schema.String,
      }),
    ),
  }),
);

export function findCodexBinaryEffect(): Effect.Effect<
  string,
  never,
  EnvironmentService | HomeDirectoryService | FileSystemService
> {
  return Effect.gen(function* () {
    const env = yield* EnvironmentService;
    const configured = yield* env.get("CODEX_BIN");
    if (configured) return configured;

    const home = yield* HomeDirectoryService;
    const fs = yield* FileSystemService;
    const homeDir = yield* home.get();
    const directBunInstall = join(homeDir, ".cache", ".bun", "bin", "codex");
    if (yield* fs.exists(directBunInstall)) return directBunInstall;
    const nixProfile = join(homeDir, ".nix-profile", "bin", "codex");
    if (yield* fs.exists(nixProfile)) return nixProfile;
    return "codex";
  });
}

export function readOpenAIRateLimitsEffect(
  config: CodexJsonRpcConfig = {},
): Effect.Effect<
  AccountRateLimitsResponse,
  Error,
  | ProcessService
  | EnvironmentService
  | HomeDirectoryService
  | FileSystemService
  | Clock.Clock
> {
  return Effect.gen(function* () {
    const codexBin = yield* findCodexBinaryEffect();
    const processes = yield* ProcessService;
    const env = yield* EnvironmentService;
    const envSnapshot = yield* env.snapshot();
    const timeoutMs = config.timeoutMs ?? 20_000;

    return yield* Effect.acquireUseRelease(
      processes.spawn(codexBin, ["app-server", "--stdio"], {
        stdio: ["pipe", "pipe", "pipe"],
        env: envSnapshot,
      }),
      (child) => {
        const readResponse = Effect.async<AccountRateLimitsResponse, Error>(
          (resume) => {
            const stdout = createInterface({ input: child.stdout });
            let stderr = "";
            let settled = false;
            let initialized = false;
            const initializeRequestId = 1;
            const rateLimitsRequestId = 2;

            const cleanup = () => {
              stdout.close();
              child.removeAllListeners("error");
              child.removeAllListeners("exit");
              child.stderr.removeAllListeners("data");
            };
            const fail = (error: Error) => {
              if (settled) return;
              settled = true;
              cleanup();
              resume(Effect.fail(error));
            };
            const succeed = (value: AccountRateLimitsResponse) => {
              if (settled) return;
              settled = true;
              cleanup();
              resume(Effect.succeed(value));
            };
            const send = (payload: unknown) =>
              child.stdin.write(`${JSON.stringify(payload)}\n`);

            child.stderr.on("data", (chunk) => {
              stderr += String(chunk);
            });
            child.on("error", (error) =>
              fail(
                error instanceof Error
                  ? error
                  : new Error(errorToString(error)),
              ),
            );
            child.on("exit", (code, signal) => {
              if (settled) return;
              const detail = stderr.trim()
                ? `: ${stderr.trim().slice(0, 500)}`
                : "";
              fail(
                new Error(
                  `codex app-server exited before returning rate limits (code=${code}, signal=${signal})${detail}`,
                ),
              );
            });

            stdout.on("line", (line) => {
              if (settled) return;
              if (!initialized) {
                if (isJsonRpcResponseFor(line, initializeRequestId)) {
                  initialized = true;
                  send({
                    jsonrpc: "2.0",
                    id: rateLimitsRequestId,
                    method: "account/rateLimits/read",
                    params: null,
                  });
                }
                return;
              }

              const parsed = Effect.runSync(
                parseRateLimitsJsonRpcLineEffect(line, rateLimitsRequestId),
              );
              if (Option.isSome(parsed)) {
                succeed(parsed.value);
                return;
              }

              const errorMessage = jsonRpcErrorFor(line, rateLimitsRequestId);
              if (errorMessage) fail(new Error(errorMessage));
            });

            send({
              jsonrpc: "2.0",
              id: initializeRequestId,
              method: "initialize",
              params: {
                clientInfo: {
                  name: "pi-custom-footer",
                  title: "Pi Custom Footer",
                  version: "1",
                },
                capabilities: {
                  experimentalApi: true,
                  optOutNotificationMethods: ["remoteControl/status/changed"],
                },
              },
            });

            return Effect.sync(cleanup);
          },
        );

        return readResponse.pipe(
          Effect.timeoutFail({
            duration: Duration.millis(timeoutMs),
            onTimeout: () =>
              new Error(`codex app-server timed out after ${timeoutMs}ms`),
          }),
        );
      },
      (child) =>
        Effect.sync(() => {
          if (!child.killed) child.kill("SIGTERM");
        }),
    );
  });
}

export function readOpenAIRateLimits(): Promise<AccountRateLimitsResponse> {
  return Effect.runPromise(
    readOpenAIRateLimitsEffect().pipe(Effect.provide(SharedLiveLayer)),
  );
}

function isJsonRpcResponseFor(line: string, requestId: number): boolean {
  const decoded = Schema.decodeUnknownEither(JsonRpcResultLineSchema)(line);
  return (
    Either.isRight(decoded) &&
    decoded.right.id === requestId &&
    Object.hasOwn(decoded.right, "result")
  );
}

function jsonRpcErrorFor(line: string, requestId: number): string | undefined {
  const decoded = Schema.decodeUnknownEither(JsonRpcErrorLineSchema)(line);
  if (Either.isLeft(decoded)) return undefined;
  return decoded.right.id === requestId
    ? decoded.right.error?.message
    : undefined;
}
