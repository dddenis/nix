export type HistoryScope = "all" | "current";

export type HistoryItemSource = "current" | "saved";

export interface HistoryItem {
	text: string;
	timestamp: number;
	sessionFile: string;
	cwd: string;
	source: HistoryItemSource;
}

export interface HistorySearchResult {
	item: HistoryItem;
	score: number;
}
