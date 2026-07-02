import type {
  ExtensionContext,
  SessionInfo,
} from "@earendil-works/pi-coding-agent";
import { Context, Deferred, Effect, Fiber, Layer, Runtime } from "effect";

import { runSyncEffect } from "../shared/effect-runtime";
import { FileSystemService, SharedLiveLayer } from "../shared/services";
import type { HistoryItem } from "./types";
import { SessionListingLiveLayer, SessionListingService } from "./services";
import {
  MalformedSessionJsonlError,
  indexCurrentSessionEntriesEffect,
  parseSavedSessionJsonlEffect,
} from "./session-items";

const LIST_FAILURE_WARNING =
  "Saved sessions unavailable; showing cached and current-session history only.";

export interface SavedSessionRefreshUpdate {
  items: HistoryItem[];
  loading: boolean;
  warning?: string;
  parsedFiles: number;
  totalFiles: number;
}

export type SavedSessionRefreshListener = (
  update: SavedSessionRefreshUpdate,
) => void;

export interface SavedSessionRefreshHandle {
  readonly awaitEffect: Effect.Effect<SavedSessionRefreshUpdate>;
  readonly promise: Promise<SavedSessionRefreshUpdate>;
  unsubscribe(): void;
}

interface SavedSessionRefreshInFlight {
  readonly awaitEffect: Effect.Effect<SavedSessionRefreshUpdate>;
  readonly deferred: Deferred.Deferred<SavedSessionRefreshUpdate>;
  readonly promise: Promise<SavedSessionRefreshUpdate>;
  fiber?: Fiber.RuntimeFiber<boolean, never>;
}

interface CachedSessionFile {
  path: string;
  mtimeMs: number;
  items: HistoryItem[];
  error?: string;
}

export class HistoryIndexer {
  private readonly cache = new Map<string, CachedSessionFile>();
  private readonly listeners = new Set<SavedSessionRefreshListener>();
  private savedItems: HistoryItem[] = [];
  private refreshInFlight: SavedSessionRefreshInFlight | undefined;
  private lastUpdate: SavedSessionRefreshUpdate = {
    items: [],
    loading: false,
    parsedFiles: 0,
    totalFiles: 0,
  };

  indexCurrentSessionEffect(
    ctx: ExtensionContext,
  ): Effect.Effect<HistoryItem[]> {
    return indexCurrentSessionEntriesEffect(
      ctx.sessionManager.getEntries(),
      ctx.cwd,
      ctx.sessionManager.getSessionFile(),
    );
  }

  indexCurrentSession(ctx: ExtensionContext): HistoryItem[] {
    return runSyncEffect(this.indexCurrentSessionEffect(ctx));
  }

  getSavedItemsEffect(): Effect.Effect<HistoryItem[]> {
    return Effect.sync(() => [...this.savedItems]);
  }

  getSavedItems(): HistoryItem[] {
    return runSyncEffect(this.getSavedItemsEffect());
  }

  startOrJoinSavedSessionRefresh(
    listener?: SavedSessionRefreshListener,
  ): SavedSessionRefreshHandle {
    return runSyncEffect(
      this.startOrJoinSavedSessionRefreshEffect(listener).pipe(
        Effect.provide(SharedLiveLayer),
        Effect.provide(SessionListingLiveLayer),
      ),
    );
  }

  startOrJoinSavedSessionRefreshEffect(
    listener?: SavedSessionRefreshListener,
  ): Effect.Effect<
    SavedSessionRefreshHandle,
    never,
    SessionListingService | FileSystemService
  > {
    const self = this;
    return Effect.gen(function* () {
      const runtime = yield* Effect.runtime<
        SessionListingService | FileSystemService
      >();

      if (listener) {
        self.listeners.add(listener);
        listener({
          ...self.lastUpdate,
          items: yield* self.getSavedItemsEffect(),
          loading: Boolean(self.refreshInFlight),
        });
      }

      let inFlight = self.refreshInFlight;
      if (!inFlight) {
        const deferred = yield* Deferred.make<
          SavedSessionRefreshUpdate,
          never
        >();
        const awaitEffect = Deferred.await(deferred);
        inFlight = {
          awaitEffect,
          deferred,
          promise: Runtime.runPromise(runtime)(awaitEffect),
        };
        self.refreshInFlight = inFlight;

        inFlight.fiber = yield* self.refreshSavedSessionsEffect().pipe(
          Effect.exit,
          Effect.flatMap((exit) => Deferred.done(deferred, exit)),
          Effect.ensuring(
            Effect.sync(() => {
              if (self.refreshInFlight?.deferred === deferred)
                self.refreshInFlight = undefined;
            }),
          ),
          Effect.forkDaemon,
        );
      }

      return {
        awaitEffect: inFlight.awaitEffect,
        promise: inFlight.promise,
        unsubscribe: () => {
          if (listener) self.listeners.delete(listener);
        },
      };
    });
  }

  private emit(update: SavedSessionRefreshUpdate): SavedSessionRefreshUpdate {
    this.lastUpdate = { ...update, items: [...update.items] };
    for (const listener of this.listeners) listener(this.lastUpdate);
    return this.lastUpdate;
  }

  private rebuildSavedItems(): HistoryItem[] {
    this.savedItems = [...this.cache.values()].flatMap(
      (cached) => cached.items,
    );
    return this.getSavedItems();
  }

  private refreshSavedSessionsEffect(): Effect.Effect<
    SavedSessionRefreshUpdate,
    never,
    SessionListingService | FileSystemService
  > {
    const self = this;
    return Effect.gen(function* () {
      const sessionListing = yield* SessionListingService;
      const fileSystem = yield* FileSystemService;
      const sessions = yield* sessionListing
        .listAll()
        .pipe(Effect.catchAll(() => Effect.succeed(undefined)));

      if (sessions === undefined) {
        return self.emit({
          items: self.getSavedItems(),
          loading: false,
          warning: LIST_FAILURE_WARNING,
          parsedFiles: 0,
          totalFiles: 0,
        });
      }

      const seenPaths = new Set(sessions.map((session) => session.path));
      for (const cachedPath of self.cache.keys()) {
        if (!seenPaths.has(cachedPath)) self.cache.delete(cachedPath);
      }

      let skipped = 0;
      let processed = 0;
      const totalFiles = sessions.length;

      if (totalFiles === 0) {
        self.rebuildSavedItems();
        return self.emit({
          items: [],
          loading: false,
          parsedFiles: 0,
          totalFiles: 0,
        });
      }

      for (const session of sessions) {
        processed++;

        yield* self.refreshSavedSessionFileEffect(session, fileSystem).pipe(
          Effect.catchAll((error) =>
            Effect.sync(() => {
              skipped++;
              self.cache.set(session.path, {
                path: session.path,
                mtimeMs: -1,
                items: [],
                error: errorToString(error),
              });
            }),
          ),
        );

        if (processed % 20 === 0 || processed === totalFiles) {
          const warning =
            skipped > 0
              ? `${skipped} saved session file(s) skipped.`
              : undefined;
          self.emit({
            items: self.rebuildSavedItems(),
            loading: processed < totalFiles,
            warning,
            parsedFiles: processed,
            totalFiles,
          });
        }
      }

      return self.lastUpdate;
    });
  }

  private refreshSavedSessionFileEffect(
    session: SessionInfo,
    fileSystem: Context.Tag.Service<FileSystemService>,
  ): Effect.Effect<void, Error | MalformedSessionJsonlError> {
    const self = this;
    return Effect.gen(function* () {
      const mtimeMs = yield* fileSystem.statMtimeMs(session.path);
      const cached = self.cache.get(session.path);

      if (!cached || cached.mtimeMs !== mtimeMs) {
        const content = yield* fileSystem.readTextFile(session.path);
        self.cache.set(session.path, {
          path: session.path,
          mtimeMs,
          items: yield* parseSavedSessionJsonlEffect(
            content,
            session.path,
            session.cwd,
          ),
        });
      }
    });
  }
}

type HistoryIndexerServiceShape = HistoryIndexer;

export class HistoryIndexerService extends Context.Tag(
  "ddd-pi-extensions/HistoryIndexerService",
)<HistoryIndexerService, HistoryIndexerServiceShape>() {}

export const HistoryIndexerLiveLayer = Layer.effect(
  HistoryIndexerService,
  Effect.sync(() => new HistoryIndexer()),
);

function errorToString(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
