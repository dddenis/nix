import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Effect, Layer, Runtime } from "effect";

import { runEffectHandler, runSyncEffect } from "../shared/effect-runtime";
import { FileSystemService, SharedLiveLayer } from "../shared/services";
import {
  TuiPrimitivesLiveLayer,
  TuiPrimitivesService,
} from "../shared/tui-primitives";
import { HistoryPickerComponent } from "./picker";
import { HistoryPickerState } from "./picker-state";
import { HistoryIndexer, HistoryIndexerService } from "./session-indexer";
import { SessionListingLiveLayer, SessionListingService } from "./services";

export function openHistoryPickerEffect(
  ctx: ExtensionContext,
): Effect.Effect<
  void,
  Error,
  | HistoryIndexerService
  | SessionListingService
  | FileSystemService
  | TuiPrimitivesService
> {
  return Effect.gen(function* () {
    const indexer = yield* HistoryIndexerService;
    const tuiPrimitives = yield* TuiPrimitivesService;
    if (ctx.mode !== "tui") {
      if (ctx.hasUI)
        yield* Effect.sync(() =>
          ctx.ui.notify(
            "History picker requires interactive TUI mode.",
            "warning",
          ),
        );
      return;
    }

    const state = new HistoryPickerState({
      currentCwd: ctx.cwd,
      query: ctx.ui.getEditorText(),
      currentItems: yield* indexer.indexCurrentSessionEffect(ctx),
      savedItems: yield* indexer.getSavedItemsEffect(),
      loading: true,
    });

    let requestRender: (() => void) | undefined;
    let component: HistoryPickerComponent | undefined;
    const input = yield* tuiPrimitives.createInput();

    const selected = yield* Effect.acquireUseRelease(
      indexer.startOrJoinSavedSessionRefreshEffect((update) => {
        state.setSavedItems(update.items);
        state.setLoading(update.loading);
        state.setWarning(update.warning);
        component?.invalidate();
        requestRender?.();
      }),
      () =>
        Effect.gen(function* () {
          return yield* Effect.tryPromise({
            try: () =>
              ctx.ui.custom<string | null>(
                (tui, theme, _keybindings, done) => {
                  requestRender = () => tui.requestRender();
                  component = new HistoryPickerComponent(
                    state,
                    theme,
                    done,
                    requestRender,
                    tuiPrimitives,
                    input,
                  );
                  return component;
                },
                {
                  overlay: true,
                  overlayOptions: {
                    width: 100,
                    minWidth: 50,
                    maxHeight: "80%",
                    margin: 2,
                  },
                },
              ),
            catch: (error) =>
              error instanceof Error ? error : new Error(String(error)),
          });
        }),
      (handle) => Effect.sync(() => handle.unsubscribe()),
    );

    if (selected !== null && selected !== undefined) {
      yield* Effect.sync(() => ctx.ui.setEditorText(selected.trim()));
    }
  });
}

export async function openHistoryPicker(ctx: ExtensionContext): Promise<void> {
  await runEffectHandler(
    openHistoryPickerWithIndexerEffect(ctx, new HistoryIndexer()).pipe(
      Effect.provide(HistoryPickerRuntimeLayer),
    ),
  );
}

export function historyPickerExtensionEffect(
  pi: ExtensionAPI,
): Effect.Effect<
  void,
  never,
  SessionListingService | FileSystemService | TuiPrimitivesService
> {
  return Effect.gen(function* () {
    const runtime = yield* Effect.runtime<
      SessionListingService | FileSystemService | TuiPrimitivesService
    >();
    const indexer = new HistoryIndexer();
    const indexerLayer = Layer.succeed(HistoryIndexerService, indexer);

    yield* Effect.sync(() => {
      pi.registerShortcut("ctrl+r", {
        description: "Search previous user messages",
        handler: async (ctx) => {
          await Runtime.runPromise(runtime)(
            openHistoryPickerEffect(ctx).pipe(Effect.provide(indexerLayer)),
          );
        },
      });
    });
  });
}

export default function historyPickerExtension(pi: ExtensionAPI): void {
  runSyncEffect(
    historyPickerExtensionEffect(pi).pipe(
      Effect.provide(HistoryPickerRuntimeLayer),
    ),
  );
}

const HistoryPickerRuntimeLayer = Layer.mergeAll(
  SharedLiveLayer,
  SessionListingLiveLayer,
  TuiPrimitivesLiveLayer,
);

function openHistoryPickerWithIndexerEffect(
  ctx: ExtensionContext,
  indexer: HistoryIndexer,
): Effect.Effect<
  void,
  Error,
  SessionListingService | FileSystemService | TuiPrimitivesService
> {
  return openHistoryPickerEffect(ctx).pipe(
    Effect.provide(Layer.succeed(HistoryIndexerService, indexer)),
  );
}
