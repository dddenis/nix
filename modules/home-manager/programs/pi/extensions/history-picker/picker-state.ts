import { searchHistoryItems } from "./history-search";
import type { HistoryItem, HistoryScope, HistorySearchResult } from "./types";

export interface HistoryPickerStateOptions {
	currentCwd: string;
	query: string;
	currentItems: HistoryItem[];
	savedItems: HistoryItem[];
	loading?: boolean;
	warning?: string;
}

export class HistoryPickerState {
	readonly currentCwd: string;
	readonly currentItems: HistoryItem[];
	query: string;
	scope: HistoryScope = "all";
	selectedIndex = 0;
	loading: boolean;
	warning: string | undefined;
	private savedItems: HistoryItem[];

	constructor(options: HistoryPickerStateOptions) {
		this.currentCwd = options.currentCwd;
		this.query = options.query;
		this.currentItems = [...options.currentItems];
		this.savedItems = [...options.savedItems];
		this.loading = options.loading ?? false;
		this.warning = options.warning;
		this.clampSelection();
	}

	setQuery(query: string): void {
		this.query = query;
		this.clampSelection();
	}

	setSavedItems(items: HistoryItem[]): void {
		this.savedItems = [...items];
		this.clampSelection();
	}

	setLoading(loading: boolean): void {
		this.loading = loading;
	}

	setWarning(warning: string | undefined): void {
		this.warning = warning;
	}

	toggleScope(): void {
		this.scope = this.scope === "all" ? "current" : "all";
		this.selectedIndex = 0;
		this.clampSelection();
	}

	moveSelection(delta: number): void {
		const results = this.getResults();
		if (results.length === 0) {
			this.selectedIndex = 0;
			return;
		}

		this.selectedIndex = Math.max(0, Math.min(results.length - 1, this.selectedIndex + delta));
	}

	getResults(): HistorySearchResult[] {
		return searchHistoryItems([...this.currentItems, ...this.savedItems], this.query, this.scope, this.currentCwd);
	}

	getSelectedItem(): HistoryItem | undefined {
		return this.getResults()[this.selectedIndex]?.item;
	}

	private clampSelection(): void {
		const results = this.getResults();
		if (results.length === 0) {
			this.selectedIndex = 0;
			return;
		}
		this.selectedIndex = Math.max(0, Math.min(this.selectedIndex, results.length - 1));
	}
}
