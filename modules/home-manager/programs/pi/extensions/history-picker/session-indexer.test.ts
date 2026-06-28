import { describe, expect, test } from "bun:test";
import type { SessionInfo } from "@earendil-works/pi-coding-agent";

import { HistoryIndexer } from "./session-indexer";

function session(path: string, cwd: string): SessionInfo {
	return {
		path,
		id: path,
		cwd,
		created: new Date(0),
		modified: new Date(0),
		messageCount: 1,
		firstMessage: "",
		allMessagesText: "",
	};
}

describe("history session indexer", () => {
	test("indexes current session entries through the active context", () => {
		const indexer = new HistoryIndexer();
		const ctx = {
			cwd: "/repo",
			sessionManager: {
				getSessionFile: () => undefined,
				getEntries: () => [
					{
						type: "message",
						id: "a",
						parentId: null,
						timestamp: "2026-06-28T10:00:00.000Z",
						message: { role: "user", content: "current prompt", timestamp: 10 },
					},
				],
			},
		};

		const items = indexer.indexCurrentSession(ctx as never);

		expect(items.map((item) => [item.text, item.cwd, item.source])).toEqual([["current prompt", "/repo", "current"]]);
	});

	test("reuses unchanged cached saved session files and reparses changed files", async () => {
		const files = new Map([
			[
				"/sessions/a.jsonl",
				{
					mtimeMs: 1,
					reads: 0,
					content: [
						JSON.stringify({ type: "session", cwd: "/repo-a" }),
						JSON.stringify({ type: "message", message: { role: "user", content: "first", timestamp: 10 } }),
					].join("\n"),
				},
			],
		]);

		const indexer = new HistoryIndexer({
			listAll: async () => [session("/sessions/a.jsonl", "/repo-a")],
			stat: async (path) => ({ mtimeMs: files.get(path)!.mtimeMs }),
			readFile: async (path) => {
				const file = files.get(path)!;
				file.reads++;
				return file.content;
			},
		});

		await indexer.startOrJoinSavedSessionRefresh().promise;
		expect(indexer.getSavedItems().map((item) => item.text)).toEqual(["first"]);
		expect(files.get("/sessions/a.jsonl")!.reads).toBe(1);

		await indexer.startOrJoinSavedSessionRefresh().promise;
		expect(files.get("/sessions/a.jsonl")!.reads).toBe(1);

		files.get("/sessions/a.jsonl")!.mtimeMs = 2;
		files.get("/sessions/a.jsonl")!.content = [
			JSON.stringify({ type: "session", cwd: "/repo-a" }),
			JSON.stringify({ type: "message", message: { role: "user", content: "second", timestamp: 20 } }),
		].join("\n");

		await indexer.startOrJoinSavedSessionRefresh().promise;
		expect(indexer.getSavedItems().map((item) => item.text)).toEqual(["second"]);
		expect(files.get("/sessions/a.jsonl")!.reads).toBe(2);
	});

	test("keeps cached saved items when listing all sessions fails", async () => {
		let shouldFail = false;
		const indexer = new HistoryIndexer({
			listAll: async () => {
				if (shouldFail) throw new Error("cannot list sessions");
				return [session("/sessions/a.jsonl", "/repo-a")];
			},
			stat: async () => ({ mtimeMs: 1 }),
			readFile: async () =>
				[
					JSON.stringify({ type: "session", cwd: "/repo-a" }),
					JSON.stringify({ type: "message", message: { role: "user", content: "cached", timestamp: 10 } }),
				].join("\n"),
		});

		await indexer.startOrJoinSavedSessionRefresh().promise;
		shouldFail = true;

		const update = await indexer.startOrJoinSavedSessionRefresh().promise;

		expect(update.warning).toBe("Saved sessions unavailable; showing cached and current-session history only.");
		expect(update.items.map((item) => item.text)).toEqual(["cached"]);
	});
});
