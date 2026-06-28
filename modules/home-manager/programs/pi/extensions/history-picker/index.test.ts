import { describe, expect, mock, test } from "bun:test";
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import type { PickerIndexer } from "./index";

function visibleWidth(value: string): number {
	return [...value.replace(/\x1b\[[0-9;]*m/g, "")].length;
}

function truncateToWidth(value: string, width: number, ellipsis = "…"): string {
	if (visibleWidth(value) <= width) return value;
	if (width <= visibleWidth(ellipsis)) return ellipsis.slice(0, Math.max(0, width));
	return [...value].slice(0, width - visibleWidth(ellipsis)).join("") + ellipsis;
}

mock.module("@earendil-works/pi-tui", () => ({
	Input: class {
		focused = false;
		private value = "";

		setValue(value: string): void {
			this.value = value;
		}

		getValue(): string {
			return this.value;
		}

		handleInput(data: string): void {
			this.value += data;
		}

		render(width: number): string[] {
			return [truncateToWidth(this.value, width, "")];
		}

		invalidate(): void {}
	},
	Key: {
		escape: "\x1b",
		up: "\x1b[A",
		down: "\x1b[B",
		enter: "\r",
		return: "\n",
		ctrl: (key: string) => `ctrl+${key}`,
	},
	matchesKey: (data: string, key: string) => data === key,
	truncateToWidth,
	visibleWidth,
}));

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
	test("registers only the ctrl+r shortcut", async () => {
		const { default: historyPickerExtension } = await import("./index");
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

		expect(shortcuts).toEqual([{ shortcut: "ctrl+r", description: "Search previous user messages" }]);
		expect(commands).toEqual([]);
	});

	test("does not index sessions outside TUI mode", async () => {
		const { openHistoryPicker } = await import("./index");
		const notifications: Array<{ message: string; level?: string }> = [];
		const indexer: PickerIndexer = {
			indexCurrentSession: () => {
				throw new Error("should not index outside TUI mode");
			},
			getSavedItems: () => [],
			startOrJoinSavedSessionRefresh: () => {
				throw new Error("should not refresh outside TUI mode");
			},
		};

		await openHistoryPicker(
			{
				mode: "rpc",
				hasUI: true,
				ui: {
					notify: (message: string, level?: string) => notifications.push({ message, level }),
				},
			} as unknown as ExtensionContext,
			indexer,
		);

		expect(notifications).toEqual([
			{ message: "History picker requires interactive TUI mode.", level: "warning" },
		]);
	});

	test("sets the editor to the selected trimmed prompt and unsubscribes refresh listeners", async () => {
		const { openHistoryPicker } = await import("./index");
		let editorText = "";
		let unsubscribed = false;
		const indexer: PickerIndexer = {
			indexCurrentSession: () => [],
			getSavedItems: () => [],
			startOrJoinSavedSessionRefresh: () => ({
				promise: Promise.resolve({ items: [], loading: false, parsedFiles: 0, totalFiles: 0 }),
				unsubscribe: () => {
					unsubscribed = true;
				},
			}),
		};

		const ctx = {
			mode: "tui",
			hasUI: true,
			cwd: "/repo",
			sessionManager: { getEntries: () => [], getSessionFile: () => undefined },
			ui: {
				getEditorText: () => "prefilled query",
				setEditorText: (text: string) => {
					editorText = text;
				},
				custom: async <T>(
					factory: (...args: unknown[]) => unknown,
					options: { overlay?: boolean; overlayOptions?: Record<string, unknown> },
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

		await openHistoryPicker(ctx as unknown as ExtensionContext, indexer);

		expect(editorText).toBe("selected prompt");
		expect(unsubscribed).toBe(true);
	});
});
