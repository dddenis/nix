import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

import { HistoryIndexer, type SavedSessionRefreshHandle } from "./session-indexer";
import { HistoryPickerComponent } from "./picker";
import { HistoryPickerState } from "./picker-state";

export type PickerIndexer = Pick<HistoryIndexer, "indexCurrentSession" | "getSavedItems" | "startOrJoinSavedSessionRefresh">;

const indexer = new HistoryIndexer();

export async function openHistoryPicker(ctx: ExtensionContext, pickerIndexer: PickerIndexer = indexer): Promise<void> {
	if (ctx.mode !== "tui") {
		if (ctx.hasUI) ctx.ui.notify("History picker requires interactive TUI mode.", "warning");
		return;
	}

	const state = new HistoryPickerState({
		currentCwd: ctx.cwd,
		query: ctx.ui.getEditorText(),
		currentItems: pickerIndexer.indexCurrentSession(ctx),
		savedItems: pickerIndexer.getSavedItems(),
		loading: true,
	});

	let requestRender: (() => void) | undefined;
	let component: HistoryPickerComponent | undefined;
	let refreshHandle: SavedSessionRefreshHandle | undefined;

	try {
		refreshHandle = pickerIndexer.startOrJoinSavedSessionRefresh((update) => {
			state.setSavedItems(update.items);
			state.setLoading(update.loading);
			state.setWarning(update.warning);
			component?.invalidate();
			requestRender?.();
		});

		const selected = await ctx.ui.custom<string | null>(
			(tui, theme, _keybindings, done) => {
				requestRender = () => tui.requestRender();
				component = new HistoryPickerComponent(state, theme, done, requestRender);
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
		);

		if (selected !== null && selected !== undefined) {
			ctx.ui.setEditorText(selected.trim());
		}
	} finally {
		refreshHandle?.unsubscribe();
	}
}

export default function historyPickerExtension(pi: ExtensionAPI): void {
	pi.registerShortcut(Key.ctrl("r"), {
		description: "Search previous user messages",
		handler: async (ctx) => {
			await openHistoryPicker(ctx);
		},
	});
}
