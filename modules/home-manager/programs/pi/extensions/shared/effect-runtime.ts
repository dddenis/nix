import { Effect, Layer, ManagedRuntime } from "effect";

export interface EffectHandlerRunner<R> {
  readonly runPromise: <A, E>(program: Effect.Effect<A, E, R>) => Promise<A>;
  readonly runSync: <A, E>(program: Effect.Effect<A, E, R>) => A;
  readonly dispose: () => Promise<void>;
}

export function runEffectHandler<A, E>(
  program: Effect.Effect<A, E, never>,
): Promise<A> {
  return Effect.runPromise(program);
}

export function runSyncEffect<A, E>(program: Effect.Effect<A, E, never>): A {
  return Effect.runSync(program);
}

export function makeManagedRuntimeRunner<R, E>(
  layer: Layer.Layer<R, E, never>,
): EffectHandlerRunner<R> {
  const runtime = ManagedRuntime.make(layer);
  return {
    runPromise: (program) => runtime.runPromise(program),
    runSync: (program) => runtime.runSync(program),
    dispose: () => runtime.dispose(),
  };
}

export function errorToString(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;

  try {
    return JSON.stringify(error) ?? String(error);
  } catch {
    return String(error);
  }
}
