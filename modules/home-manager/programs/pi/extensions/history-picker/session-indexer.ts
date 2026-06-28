import { readFile as defaultReadFile, stat as defaultStat } from "node:fs/promises";
import type { Stats } from "node:fs";
import type { ExtensionContext, SessionInfo } from "@earendil-works/pi-coding-agent";

import type { HistoryItem } from "./types";
import { indexCurrentSessionEntries, parseSavedSessionJsonl } from "./session-items";

const LIST_FAILURE_WARNING = "Saved sessions unavailable; showing cached and current-session history only.";

export interface SavedSessionRefreshUpdate {
	items: HistoryItem[];
	loading: boolean;
	warning?: string;
	parsedFiles: number;
	totalFiles: number;
}

export type SavedSessionRefreshListener = (update: SavedSessionRefreshUpdate) => void;

export interface SavedSessionRefreshHandle {
	promise: Promise<SavedSessionRefreshUpdate>;
	unsubscribe(): void;
}

type StatFile = (path: string) => Promise<Pick<Stats, "mtimeMs">>;
type ReadTextFile = (path: string) => Promise<string>;
type ListAllSessions = () => Promise<SessionInfo[]>;

export interface HistoryIndexerDeps {
	listAll?: ListAllSessions;
	stat?: StatFile;
	readFile?: ReadTextFile;
}

interface CachedSessionFile {
	path: string;
	mtimeMs: number;
	items: HistoryItem[];
	error?: string;
}

export class HistoryIndexer {
	private readonly listAll: ListAllSessions;
	private readonly stat: StatFile;
	private readonly readFile: ReadTextFile;
	private readonly cache = new Map<string, CachedSessionFile>();
	private readonly listeners = new Set<SavedSessionRefreshListener>();
	private savedItems: HistoryItem[] = [];
	private refreshInFlight: Promise<SavedSessionRefreshUpdate> | undefined;
	private lastUpdate: SavedSessionRefreshUpdate = {
		items: [],
		loading: false,
		parsedFiles: 0,
		totalFiles: 0,
	};

	constructor(deps: HistoryIndexerDeps = {}) {
		this.listAll =
			deps.listAll ??
			(async () => {
				const { SessionManager } = await import("@earendil-works/pi-coding-agent");
				return SessionManager.listAll();
			});
		this.stat = deps.stat ?? defaultStat;
		this.readFile = deps.readFile ?? ((path) => defaultReadFile(path, "utf8") as Promise<string>);
	}

	indexCurrentSession(ctx: ExtensionContext): HistoryItem[] {
		return indexCurrentSessionEntries(ctx.sessionManager.getEntries(), ctx.cwd, ctx.sessionManager.getSessionFile());
	}

	getSavedItems(): HistoryItem[] {
		return [...this.savedItems];
	}

	startOrJoinSavedSessionRefresh(listener?: SavedSessionRefreshListener): SavedSessionRefreshHandle {
		if (listener) {
			this.listeners.add(listener);
			listener({ ...this.lastUpdate, items: this.getSavedItems(), loading: Boolean(this.refreshInFlight) });
		}

		if (!this.refreshInFlight) {
			this.refreshInFlight = this.refreshSavedSessions().finally(() => {
				this.refreshInFlight = undefined;
			});
		}

		return {
			promise: this.refreshInFlight,
			unsubscribe: () => {
				if (listener) this.listeners.delete(listener);
			},
		};
	}

	private emit(update: SavedSessionRefreshUpdate): SavedSessionRefreshUpdate {
		this.lastUpdate = { ...update, items: [...update.items] };
		for (const listener of this.listeners) listener(this.lastUpdate);
		return this.lastUpdate;
	}

	private rebuildSavedItems(): HistoryItem[] {
		this.savedItems = [...this.cache.values()].flatMap((cached) => cached.items);
		return this.getSavedItems();
	}

	private async refreshSavedSessions(): Promise<SavedSessionRefreshUpdate> {
		let sessions: SessionInfo[];

		try {
			sessions = await this.listAll();
		} catch {
			return this.emit({
				items: this.getSavedItems(),
				loading: false,
				warning: LIST_FAILURE_WARNING,
				parsedFiles: 0,
				totalFiles: 0,
			});
		}

		const seenPaths = new Set(sessions.map((session) => session.path));
		for (const cachedPath of this.cache.keys()) {
			if (!seenPaths.has(cachedPath)) this.cache.delete(cachedPath);
		}

		let skipped = 0;
		let processed = 0;
		const totalFiles = sessions.length;

		if (totalFiles === 0) {
			this.rebuildSavedItems();
			return this.emit({ items: [], loading: false, parsedFiles: 0, totalFiles: 0 });
		}

		for (const session of sessions) {
			processed++;

			try {
				const fileStat = await this.stat(session.path);
				const cached = this.cache.get(session.path);

				if (!cached || cached.mtimeMs !== fileStat.mtimeMs) {
					const content = await this.readFile(session.path);
					this.cache.set(session.path, {
						path: session.path,
						mtimeMs: fileStat.mtimeMs,
						items: parseSavedSessionJsonl(content, session.path, session.cwd),
					});
				}
			} catch (error) {
				skipped++;
				this.cache.set(session.path, {
					path: session.path,
					mtimeMs: -1,
					items: [],
					error: error instanceof Error ? error.message : String(error),
				});
			}

			if (processed % 20 === 0 || processed === totalFiles) {
				const warning = skipped > 0 ? `${skipped} saved session file(s) skipped.` : undefined;
				this.emit({
					items: this.rebuildSavedItems(),
					loading: processed < totalFiles,
					warning,
					parsedFiles: processed,
					totalFiles,
				});
			}
		}

		return this.lastUpdate;
	}
}
