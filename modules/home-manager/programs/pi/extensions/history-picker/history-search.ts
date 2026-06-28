import type { HistoryItem, HistoryScope, HistorySearchResult } from "./types";

const WORD_START_BOUNDARY = /[\s\-_/.:()[\]{}]/;

function isWordStart(text: string, index: number): boolean {
	return index === 0 || WORD_START_BOUNDARY.test(text[index - 1] ?? "");
}

export function scoreFuzzy(query: string, text: string): number | null {
	const needle = query.trim().toLowerCase();
	if (needle.length === 0) return 0;

	const haystack = text.toLowerCase();
	let lastIndex = -1;
	let firstIndex = -1;
	let score = needle.length * 20;

	for (const char of needle) {
		const index = haystack.indexOf(char, lastIndex + 1);
		if (index === -1) return null;

		if (firstIndex === -1) firstIndex = index;
		if (index === lastIndex + 1) score += 35;
		if (isWordStart(haystack, index)) score += 25;

		const gap = lastIndex === -1 ? index : index - lastIndex - 1;
		score -= Math.min(gap, 30);
		lastIndex = index;
	}

	const substringIndex = haystack.indexOf(needle);
	if (substringIndex !== -1) {
		score += 1000;
		score += Math.max(0, 200 - substringIndex);
	}

	if (firstIndex !== -1) score += Math.max(0, 80 - firstIndex);
	return score;
}

function filterByScope(items: readonly HistoryItem[], scope: HistoryScope, currentCwd: string): HistoryItem[] {
	if (scope === "all") return [...items];
	return items.filter((item) => item.cwd === currentCwd);
}

export function dedupeHistoryItems(items: readonly HistoryItem[]): HistoryItem[] {
	const byText = new Map<string, HistoryItem>();

	for (const item of items) {
		const existing = byText.get(item.text);
		if (!existing || item.timestamp > existing.timestamp) {
			byText.set(item.text, item);
		}
	}

	return [...byText.values()];
}

export function searchHistoryItems(
	items: readonly HistoryItem[],
	query: string,
	scope: HistoryScope,
	currentCwd: string,
): HistorySearchResult[] {
	const scoped = filterByScope(items, scope, currentCwd);
	const deduped = dedupeHistoryItems(scoped);
	const trimmedQuery = query.trim();

	if (trimmedQuery.length === 0) {
		return deduped
			.map((item) => ({ item, score: 0 }))
			.sort((a, b) => b.item.timestamp - a.item.timestamp || a.item.text.localeCompare(b.item.text));
	}

	return deduped
		.map((item) => ({ item, score: scoreFuzzy(trimmedQuery, item.text) }))
		.filter((result): result is HistorySearchResult => result.score !== null)
		.sort((a, b) => b.score - a.score || b.item.timestamp - a.item.timestamp || a.item.text.localeCompare(b.item.text));
}
