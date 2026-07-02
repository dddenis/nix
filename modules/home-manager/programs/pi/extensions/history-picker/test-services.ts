import type { SessionInfo } from "@earendil-works/pi-coding-agent";
import { Context, Effect, Layer, Ref } from "effect";
import { SessionListingService } from "./services";

interface HistoryPickerServicesTestState {
  readonly sessions: readonly SessionInfo[];
  readonly listError: Error | undefined;
  readonly listCalls: readonly { readonly index: number }[];
}

interface HistoryPickerServicesTestShape {
  readonly setSessions: (
    sessions: readonly SessionInfo[],
  ) => Effect.Effect<void>;
  readonly setListError: (error: Error | undefined) => Effect.Effect<void>;
  readonly getState: Effect.Effect<HistoryPickerServicesTestState>;
  readonly resetCalls: Effect.Effect<void>;
  readonly reset: Effect.Effect<void>;
}

const initialState = (): HistoryPickerServicesTestState => ({
  sessions: [],
  listError: undefined,
  listCalls: [],
});

export class HistoryPickerServicesTest extends Context.Tag(
  "ddd-pi-extensions/HistoryPickerServicesTest",
)<HistoryPickerServicesTest, HistoryPickerServicesTestShape>() {
  static readonly layer = Layer.unwrapEffect(
    Effect.gen(function* () {
      const state = yield* Ref.make(initialState());
      const controls: HistoryPickerServicesTestShape = {
        setSessions: (sessions) =>
          Ref.update(state, (current) => ({
            ...current,
            sessions: [...sessions],
          })),
        setListError: (error) =>
          Ref.update(state, (current) => ({ ...current, listError: error })),
        getState: Ref.get(state).pipe(
          Effect.map((current) => ({
            ...current,
            sessions: [...current.sessions],
            listCalls: [...current.listCalls],
          })),
        ),
        resetCalls: Ref.update(state, (current) => ({
          ...current,
          listCalls: [],
        })),
        reset: Ref.set(state, initialState()),
      };

      return Layer.mergeAll(
        Layer.succeed(HistoryPickerServicesTest, controls),
        Layer.succeed(SessionListingService, {
          listAll: () =>
            Ref.modify(state, (current) => {
              const withCall = {
                ...current,
                listCalls: [
                  ...current.listCalls,
                  { index: current.listCalls.length },
                ],
              };
              return [
                current.listError
                  ? Effect.fail(current.listError)
                  : Effect.succeed([...current.sessions]),
                withCall,
              ];
            }).pipe(Effect.flatten),
        }),
      );
    }),
  );
}
