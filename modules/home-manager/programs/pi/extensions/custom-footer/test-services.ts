import { Context, Effect, Layer, Ref } from "effect";
import type { AccountRateLimitsResponse } from "./helpers";
import { JitterService, RateLimitClientService } from "./services";

type ReadResult =
  | { readonly _tag: "success"; readonly response: AccountRateLimitsResponse }
  | { readonly _tag: "failure"; readonly error: Error };

interface CustomFooterServicesTestState {
  readonly queuedReads: readonly ReadResult[];
  readonly queuedJitter: readonly number[];
  readonly readCalls: readonly { readonly index: number }[];
  readonly jitterCalls: readonly { readonly index: number }[];
}

interface CustomFooterServicesTestShape {
  readonly enqueueRateLimitResponse: (
    response: AccountRateLimitsResponse,
  ) => Effect.Effect<void>;
  readonly enqueueReadFailure: (error: Error) => Effect.Effect<void>;
  readonly enqueueJitterMultiplier: (multiplier: number) => Effect.Effect<void>;
  readonly getState: Effect.Effect<CustomFooterServicesTestState>;
  readonly resetCalls: Effect.Effect<void>;
  readonly reset: Effect.Effect<void>;
}

const initialState = (): CustomFooterServicesTestState => ({
  queuedReads: [],
  queuedJitter: [],
  readCalls: [],
  jitterCalls: [],
});

export class CustomFooterServicesTest extends Context.Tag(
  "ddd-pi-extensions/CustomFooterServicesTest",
)<CustomFooterServicesTest, CustomFooterServicesTestShape>() {
  static readonly layer = Layer.unwrapEffect(
    Effect.gen(function* () {
      const state = yield* Ref.make(initialState());
      const controls: CustomFooterServicesTestShape = {
        enqueueRateLimitResponse: (response) =>
          Ref.update(state, (current) => ({
            ...current,
            queuedReads: [
              ...current.queuedReads,
              { _tag: "success", response },
            ],
          })),
        enqueueReadFailure: (error) =>
          Ref.update(state, (current) => ({
            ...current,
            queuedReads: [...current.queuedReads, { _tag: "failure", error }],
          })),
        enqueueJitterMultiplier: (multiplier) =>
          Ref.update(state, (current) => ({
            ...current,
            queuedJitter: [...current.queuedJitter, multiplier],
          })),
        getState: Ref.get(state).pipe(
          Effect.map((current) => ({
            ...current,
            queuedReads: [...current.queuedReads],
            queuedJitter: [...current.queuedJitter],
            readCalls: [...current.readCalls],
            jitterCalls: [...current.jitterCalls],
          })),
        ),
        resetCalls: Ref.update(state, (current) => ({
          ...current,
          readCalls: [],
          jitterCalls: [],
        })),
        reset: Ref.set(state, initialState()),
      };

      return Layer.mergeAll(
        Layer.succeed(CustomFooterServicesTest, controls),
        Layer.succeed(RateLimitClientService, {
          read: () =>
            Ref.modify(state, (current) => {
              const [next, ...rest] = current.queuedReads;
              const withCall = {
                ...current,
                queuedReads: rest,
                readCalls: [
                  ...current.readCalls,
                  { index: current.readCalls.length },
                ],
              };
              if (!next)
                return [
                  Effect.dieMessage("Missing rate-limit response fixture"),
                  withCall,
                ];
              return [
                next._tag === "success"
                  ? Effect.succeed(next.response)
                  : Effect.fail(next.error),
                withCall,
              ];
            }).pipe(Effect.flatten),
        }),
        Layer.succeed(JitterService, {
          nextMultiplier: () =>
            Ref.modify(state, (current) => {
              const [next, ...rest] = current.queuedJitter;
              const withCall = {
                ...current,
                queuedJitter: rest,
                jitterCalls: [
                  ...current.jitterCalls,
                  { index: current.jitterCalls.length },
                ],
              };
              return [
                next === undefined
                  ? Effect.dieMessage("Missing jitter multiplier fixture")
                  : Effect.succeed(next),
                withCall,
              ];
            }).pipe(Effect.flatten),
        }),
      );
    }),
  );
}
