import { it } from "@effect/vitest";
import { Effect, Layer } from "effect";
import { describe, expect, test } from "vitest";
import type {
  ExtensionAPI,
  ExtensionContext,
  Theme,
} from "@earendil-works/pi-coding-agent";

import { SharedServicesTest, TuiPrimitivesTest } from "../shared/test-services";
import historyPickerExtension, {
  historyPickerExtensionEffect,
  openHistoryPicker,
  openHistoryPickerEffect,
} from "./index";
import {
  HistoryIndexer,
  HistoryIndexerLiveLayer,
  HistoryIndexerService,
} from "./session-indexer";
import { HistoryPickerServicesTest } from "./test-services";

function fakeTheme(): Theme {
  return {
    fg: (_name: string, text: string) => text,
    bg: (_name: string, text: string) => text,
    bold: (text: string) => text,
    italic: (text: string) => text,
    strikethrough: (text: string) => text,
  } as Theme;
}

describe("history picker extension", () => {
  test("registers only the ctrl+r shortcut", () => {
    const shortcuts: Array<{ shortcut: string; description?: string }> = [];
    const commands: string[] = [];

    historyPickerExtension({
      registerShortcut(shortcut, options) {
        shortcuts.push({ shortcut, description: options.description });
      },
      registerCommand(name) {
        commands.push(name);
      },
    } as unknown as ExtensionAPI);

    expect(shortcuts).toEqual([
      { shortcut: "ctrl+r", description: "Search previous user messages" },
    ]);
    expect(commands).toEqual([]);
  });

  it.effect(
    "uses one saved-session cache across shortcut invocations in the default registration path",
    () =>
      Effect.gen(function* () {
        const shared = yield* SharedServicesTest;
        yield* shared.putFile("/sessions/a.jsonl", {
          mtimeMs: 1,
          content: [
            JSON.stringify({ type: "session", cwd: "/repo-a" }),
            JSON.stringify({
              type: "message",
              message: {
                role: "user",
                content: "cached prompt",
                timestamp: 10,
              },
            }),
          ].join("\n"),
        });
        const historyServices = yield* HistoryPickerServicesTest;
        yield* historyServices.setSessions([
          {
            path: "/sessions/a.jsonl",
            id: "/sessions/a.jsonl",
            cwd: "/repo-a",
            created: new Date(0),
            modified: new Date(0),
            messageCount: 1,
            firstMessage: "",
            allMessagesText: "",
          },
        ]);

        let handler:
          ((ctx: ExtensionContext) => Promise<void> | void) | undefined;
        yield* historyPickerExtensionEffect({
          registerShortcut(_shortcut, options) {
            handler = options.handler;
          },
        } as unknown as ExtensionAPI);

        const renderedPickers: string[][] = [];
        const makeContext = (): ExtensionContext =>
          ({
            mode: "tui",
            hasUI: true,
            cwd: "/repo-a",
            sessionManager: {
              getEntries: () => [],
              getSessionFile: () => undefined,
            },
            ui: {
              getEditorText: () => "",
              setEditorText() {},
              custom: async <T>(
                factory: (...args: unknown[]) => {
                  render(width: number): string[];
                },
              ) => {
                const component = factory(
                  { requestRender() {} },
                  fakeTheme(),
                  {},
                  () => undefined,
                );
                renderedPickers.push(component.render(100));
                await new Promise((resolve) => setTimeout(resolve, 0));
                return null as T;
              },
            },
          }) as unknown as ExtensionContext;

        expect(handler).toBeDefined();
        yield* Effect.promise(() => Promise.resolve(handler!(makeContext())));
        yield* Effect.promise(() => Promise.resolve(handler!(makeContext())));

        expect(renderedPickers.at(-1)?.join("\n")).toContain("cached prompt");
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(HistoryPickerServicesTest.layer),
        Effect.provide(TuiPrimitivesTest.layer),
      ),
  );

  it.effect(
    "warns in non-TUI mode through the Effect boundary before listing sessions",
    () =>
      Effect.gen(function* () {
        const notifications: Array<{ message: string; level?: string }> = [];
        const historyServices = yield* HistoryPickerServicesTest;
        yield* historyServices.setListError(new Error("should not list"));

        yield* openHistoryPickerEffect({
          mode: "rpc",
          hasUI: true,
          ui: {
            notify: (message: string, level?: string) =>
              notifications.push({ message, level }),
          },
        } as unknown as ExtensionContext);

        expect(notifications).toEqual([
          {
            message: "History picker requires interactive TUI mode.",
            level: "warning",
          },
        ]);
        expect((yield* historyServices.getState).listCalls).toEqual([]);
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(HistoryPickerServicesTest.layer),
        Effect.provide(TuiPrimitivesTest.layer),
        Effect.provide(HistoryIndexerLiveLayer),
      ),
  );

  test("warns through the Promise wrapper outside TUI mode", async () => {
    const notifications: Array<{ message: string; level?: string }> = [];

    await openHistoryPicker({
      mode: "rpc",
      hasUI: true,
      ui: {
        notify: (message: string, level?: string) =>
          notifications.push({ message, level }),
      },
    } as unknown as ExtensionContext);

    expect(notifications).toEqual([
      {
        message: "History picker requires interactive TUI mode.",
        level: "warning",
      },
    ]);
  });

  it.effect(
    "sets the editor to the selected trimmed prompt and unsubscribes refresh listeners",
    () => {
      const indexer = new HistoryIndexer();
      let editorText = "";
      const ctx = {
        mode: "tui",
        hasUI: true,
        cwd: "/repo",
        sessionManager: {
          getEntries: () => [],
          getSessionFile: () => undefined,
        },
        ui: {
          getEditorText: () => "prefilled query",
          setEditorText: (text: string) => {
            editorText = text;
          },
          custom: async <T>(
            factory: (...args: unknown[]) => unknown,
            options: {
              overlay?: boolean;
              overlayOptions?: Record<string, unknown>;
            },
          ) => {
            expect(options.overlay).toBe(true);
            expect(options.overlayOptions).toEqual({
              width: 100,
              minWidth: 50,
              maxHeight: "80%",
              margin: 2,
            });
            factory({ requestRender() {} }, fakeTheme(), {}, () => undefined);
            return "  selected prompt  " as T;
          },
        },
      };

      return Effect.gen(function* () {
        const historyServices = yield* HistoryPickerServicesTest;
        yield* historyServices.setSessions([]);

        yield* openHistoryPickerEffect(ctx as unknown as ExtensionContext);

        expect(editorText).toBe("selected prompt");
        expect(
          (indexer as unknown as { listeners: Set<unknown> }).listeners.size,
        ).toBe(0);
      }).pipe(
        Effect.provide(SharedServicesTest.layer),
        Effect.provide(HistoryPickerServicesTest.layer),
        Effect.provide(TuiPrimitivesTest.layer),
        Effect.provide(Layer.succeed(HistoryIndexerService, indexer)),
      );
    },
  );
});
