import type { Theme } from "@earendil-works/pi-coding-agent";
import type { Component, Focusable } from "@earendil-works/pi-tui";
import { Input, Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

import type { HistorySearchResult } from "./types";
import { HistoryPickerState } from "./picker-state";

const MAX_VISIBLE_RESULTS = 12;

export class HistoryPickerComponent implements Component, Focusable {
	private readonly input = new Input();
	private readonly state: HistoryPickerState;
	private readonly theme: Theme;
	private readonly done: (value: string | null) => void;
	private readonly requestRender: () => void;
	private _focused = false;

	constructor(state: HistoryPickerState, theme: Theme, done: (value: string | null) => void, requestRender: () => void) {
		this.state = state;
		this.theme = theme;
		this.done = done;
		this.requestRender = requestRender;
		this.input.setValue(state.query);
	}

	get focused(): boolean {
		return this._focused;
	}

	set focused(value: boolean) {
		this._focused = value;
		this.input.focused = value;
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.done(null);
			return;
		}

		if (matchesKey(data, Key.ctrl("p"))) {
			this.state.toggleScope();
			this.invalidate();
			this.requestRender();
			return;
		}

		if (matchesKey(data, Key.up)) {
			this.state.moveSelection(-1);
			this.invalidate();
			this.requestRender();
			return;
		}

		if (matchesKey(data, Key.down)) {
			this.state.moveSelection(1);
			this.invalidate();
			this.requestRender();
			return;
		}

		if (matchesKey(data, Key.enter) || matchesKey(data, Key.return)) {
			const selected = this.state.getSelectedItem();
			if (selected) this.done(selected.text.trim());
			return;
		}

		const before = this.input.getValue();
		this.input.handleInput(data);
		const after = this.input.getValue();
		if (after !== before) this.state.setQuery(after);
		this.invalidate();
		this.requestRender();
	}

	render(width: number): string[] {
		if (width <= 0) return [];
		if (width === 1) return [this.theme.fg("border", "│")];

		const boxWidth = Math.min(width, 100);
		const innerWidth = boxWidth - 2;
		const border = this.theme.fg("border", "│");
		const lines: string[] = [];
		const results = this.state.getResults();

		const pad = (content: string): string => {
			if (innerWidth <= 0) return "";
			const truncated = truncateToWidth(content, innerWidth, "…");
			return truncated + " ".repeat(Math.max(0, innerWidth - visibleWidth(truncated)));
		};

		const row = (content: string): string => `${border}${pad(content)}${border}`;
		const top = this.theme.fg("border", `╭${"─".repeat(innerWidth)}╮`);
		const bottom = this.theme.fg("border", `╰${"─".repeat(innerWidth)}╯`);

		lines.push(top);
		lines.push(row(` ${this.theme.fg("accent", this.theme.bold("History Picker"))}`));
		lines.push(row(this.statusText(results)));

		const inputPrefix = ` ${this.theme.fg("dim", "Query:")} `;
		const inputWidth = Math.max(1, innerWidth - visibleWidth(" Query: "));
		const inputLine = this.input.render(inputWidth)[0] ?? "";
		lines.push(row(`${inputPrefix}${inputLine}`));
		lines.push(row(""));

		if (results.length === 0) {
			lines.push(row(` ${this.theme.fg("muted", "No matching user prompts")}`));
		} else {
			for (let index = 0; index < Math.min(results.length, MAX_VISIBLE_RESULTS); index++) {
				lines.push(row(this.resultLine(results[index]!, index === this.state.selectedIndex, innerWidth)));
			}
		}

		lines.push(row(""));
		lines.push(row(` ${this.theme.fg("dim", "↑↓ move • Enter use • Esc cancel • Ctrl+P scope")}`));
		lines.push(bottom);
		return lines;
	}

	invalidate(): void {
		this.input.invalidate();
	}

	dispose(): void {}

	private statusText(results: HistorySearchResult[]): string {
		const scope = this.state.scope === "all" ? "All projects" : "Current project";
		const loading = this.state.loading ? " • loading saved sessions" : "";
		const warning = this.state.warning ? ` • ${this.state.warning}` : "";
		return ` ${this.theme.fg("muted", `${scope} • ${results.length} result(s)${loading}${warning}`)}`;
	}

	private resultLine(result: HistorySearchResult, selected: boolean, innerWidth: number): string {
		const prefix = selected ? this.theme.fg("accent", "› ") : "  ";
		const preview = result.item.text.replace(/\s+/g, " ").trim();
		const textWidth = Math.max(1, innerWidth - visibleWidth(prefix));
		const text = truncateToWidth(preview, textWidth, "…");
		return prefix + (selected ? this.theme.fg("accent", text) : this.theme.fg("text", text));
	}
}
