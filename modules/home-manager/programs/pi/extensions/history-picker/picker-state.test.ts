import { describe, expect, mock, test } from "bun:test";

import { HistoryPickerState } from "./picker-state";
import type { HistoryItem } from "./types";

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
		ctrl: (key: string) => `ctrl-${key}`,
	},
	matchesKey: (data: string, key: string) => data === key,
	truncateToWidth,
	visibleWidth,
}));

function item(overrides: Partial<HistoryItem>): HistoryItem {
	return {
		text: "default prompt",
		timestamp: 1,
		sessionFile: "/sessions/default.jsonl",
		cwd: "/repo-a",
		source: "saved",
		...overrides,
	};
}

function plainTheme() {
	return {
		fg: (_role: string, value: string) => value,
		bold: (value: string) => value,
	};
}

describe("history picker state", () => {
	test("uses the initial editor text as query", () => {
		const state = new HistoryPickerState({
			currentCwd: "/repo-a",
			query: "pick",
			currentItems: [item({ text: "history picker", source: "current" })],
			savedItems: [item({ text: "other prompt" })],
		});

		expect(state.query).toBe("pick");
		expect(state.getResults().map((result) => result.item.text)).toEqual(["history picker"]);
	});

	test("toggles between all projects and current project", () => {
		const state = new HistoryPickerState({
			currentCwd: "/repo-a",
			query: "",
			currentItems: [item({ text: "local", timestamp: 1, cwd: "/repo-a", source: "current" })],
			savedItems: [item({ text: "remote", timestamp: 2, cwd: "/repo-b" })],
		});

		expect(state.scope).toBe("all");
		expect(state.getResults().map((result) => result.item.text)).toEqual(["remote", "local"]);

		state.toggleScope();

		expect(state.scope).toBe("current");
		expect(state.getResults().map((result) => result.item.text)).toEqual(["local"]);
	});

	test("clamps selection when query changes shrink the result set", () => {
		const state = new HistoryPickerState({
			currentCwd: "/repo-a",
			query: "",
			currentItems: [],
			savedItems: [
				item({ text: "alpha", timestamp: 3 }),
				item({ text: "beta", timestamp: 2 }),
				item({ text: "gamma", timestamp: 1 }),
			],
		});

		state.moveSelection(2);
		expect(state.selectedIndex).toBe(2);

		state.setQuery("alp");

		expect(state.selectedIndex).toBe(0);
		expect(state.getSelectedItem()?.text).toBe("alpha");
	});
});

describe("history picker component", () => {
	test("renders every visible line within the provided narrow width", async () => {
		const { HistoryPickerComponent } = await import("./picker");
		const state = new HistoryPickerState({
			currentCwd: "/repo-a",
			query: "",
			currentItems: [],
			savedItems: [item({ text: "a long saved prompt that should be truncated", timestamp: 1 })],
		});
		const component = new HistoryPickerComponent(state, plainTheme(), () => {}, () => {});

		const lines = component.render(20);

		expect(lines.length).toBeGreaterThan(0);
		for (const line of lines) {
			expect(visibleWidth(line)).toBeLessThanOrEqual(20);
		}
	});
});
