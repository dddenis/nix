import type { SessionInfo } from "@earendil-works/pi-coding-agent";
import { Context, Effect, Layer } from "effect";

type SessionListingServiceShape = {
  readonly listAll: () => Effect.Effect<SessionInfo[], Error>;
};

export class SessionListingService extends Context.Tag(
  "ddd-pi-extensions/SessionListingService",
)<SessionListingService, SessionListingServiceShape>() {}

export const SessionListingLiveLayer = Layer.succeed(SessionListingService, {
  listAll: () =>
    Effect.tryPromise({
      try: async () => {
        const { SessionManager } =
          await import("@earendil-works/pi-coding-agent");
        return SessionManager.listAll();
      },
      catch: (error) =>
        error instanceof Error ? error : new Error(String(error)),
    }),
});
