import type { HistoryItem, HistoryItemSource } from "./types";

export const CURRENT_SESSION_FILE = "<current-session>";

type AnyRecord = Record<string, unknown>;

function isRecord(value: unknown): value is AnyRecord {
	return typeof value === "object" && value !== null;
}

export function extractUserMessageText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";

	return content
		.filter((block): block is { type: "text"; text: string } => {
			return isRecord(block) && block.type === "text" && typeof block.text === "string";
		})
		.map((block) => block.text)
		.join("\n");
}

function timestampMs(entry: AnyRecord, message: AnyRecord): number {
	if (typeof message.timestamp === "number" && Number.isFinite(message.timestamp)) return message.timestamp;
	if (typeof entry.timestamp === "string") {
		const parsed = Date.parse(entry.timestamp);
		if (Number.isFinite(parsed)) return parsed;
	}
	return 0;
}

function itemFromMessageEntry(
	entry: unknown,
	source: HistoryItemSource,
	sessionFile: string,
	cwd: string,
): HistoryItem | null {
	if (!isRecord(entry) || entry.type !== "message" || !isRecord(entry.message)) return null;
	if (entry.message.role !== "user") return null;

	const text = extractUserMessageText(entry.message.content).trim();
	if (text.length === 0) return null;

	return {
		text,
		timestamp: timestampMs(entry, entry.message),
		sessionFile,
		cwd,
		source,
	};
}

export function indexCurrentSessionEntries(
	entries: readonly unknown[],
	cwd: string,
	sessionFile = CURRENT_SESSION_FILE,
): HistoryItem[] {
	return entries
		.map((entry) => itemFromMessageEntry(entry, "current", sessionFile, cwd))
		.filter((item): item is HistoryItem => item !== null);
}

export function parseSavedSessionJsonl(content: string, sessionFile: string, fallbackCwd = ""): HistoryItem[] {
	const lines = content.split(/\r?\n/).filter((line) => line.trim().length > 0);
	let cwd = fallbackCwd;
	const items: HistoryItem[] = [];

	for (let index = 0; index < lines.length; index++) {
		const line = lines[index]!;
		let parsed: unknown;

		try {
			parsed = JSON.parse(line);
		} catch {
			throw new Error(`Malformed session JSONL at ${sessionFile}:${index + 1}`);
		}

		if (!isRecord(parsed)) continue;

		if (parsed.type === "session") {
			if (typeof parsed.cwd === "string") cwd = parsed.cwd;
			continue;
		}

		const item = itemFromMessageEntry(parsed, "saved", sessionFile, cwd);
		if (item) items.push(item);
	}

	return items;
}
