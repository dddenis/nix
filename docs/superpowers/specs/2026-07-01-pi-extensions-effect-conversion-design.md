# Pi Extensions Effect Conversion Design

## Purpose

Convert the repo-managed Pi extensions under `modules/home-manager/programs/pi/extensions/` to an Effect-first internal style while preserving their current behavior and Pi extension entrypoints.

## Scope

In scope:

- `modules/home-manager/programs/pi/extensions/attention-hooks`
- `modules/home-manager/programs/pi/extensions/custom-footer`
- `modules/home-manager/programs/pi/extensions/history-picker`
- Shared package and test-runner setup under `modules/home-manager/programs/pi/extensions/`
- Test migration from Bun's test runner to Node + Vitest + `@effect/vitest`

Out of scope:

- Third-party Pi packages installed under `~/.pi/agent/npm`
- Pi itself, `pi-subagents`, `pi-intercom`, `pi-web-access`, or `@juicesharp/rpiv-todo`
- Unrelated Nix/Home Manager failures or package updates
- Broad Nix refactors unrelated to making these extensions work with their shared package setup
- Dedicated dependency/runtime smoke coverage for the shared `effect` dependency

## Accepted Decisions

- Convert the three repo-managed extensions only.
- Use a full internal Effect style, not only IO-boundary wrappers.
- Add one shared package at `modules/home-manager/programs/pi/extensions/` for all three extensions.
- Use Node to run tests.
- Install and use `vitest` and `@effect/vitest` for tests.
- Skip dedicated dependency/runtime smoke coverage for the shared `effect` dependency.
- Keep Pi extension entrypoints as normal default factory functions because Pi requires that shape.

## Current Context

Home Manager symlinks each extension directory into `~/.pi/agent/extensions/*` from `modules/home-manager/programs/pi/default.nix`. The extension source files are plain TypeScript and currently run without a repo-local build step, `package.json`, lockfile, or `tsconfig`.

Existing tests are Bun tests beside the extension sources. The current baseline command passes:

```bash
env -u PI_SUBAGENT_CHILD bun test modules/home-manager/programs/pi/extensions/**/*.test.ts
```

The `PI_SUBAGENT_CHILD` variable must be unset for the existing `attention-hooks` tests because that extension suppresses sounds in subagent child processes.

## Architecture

Add shared package setup at:

- `modules/home-manager/programs/pi/extensions/package.json`
- package lockfile created by npm
- optional shared Effect helper modules under `modules/home-manager/programs/pi/extensions/shared/` if repeated adapter code appears

The shared package will include:

- `dependencies.effect`
- `devDependencies.vitest`
- `devDependencies.@effect/vitest`
- a test script runnable with `node --run test`

Pi-facing boundaries remain compatible:

- Each extension keeps its existing `export default function (pi: ExtensionAPI)` factory.
- Pi event handlers, command handlers, shortcut handlers, and UI callbacks remain in the callback shapes Pi expects.
- Those callback boundaries adapt into Effect with `Effect.runPromise` for async handlers and `Effect.runSync` for synchronous render/decision boundaries.

Internal implementation becomes Effect-first:

- Internal computations should expose Effect-returning functions as their primary APIs.
- Pure branches may use `Effect.succeed`, `Option`, `Either`, `Match`, or small Effect pipelines instead of directly returning raw values.
- TypeScript type guards and trivial constants may remain plain where they are required for type narrowing or module structure.
- Resourceful behavior uses explicit Effect constructs such as `Effect.acquireRelease`, `Scope`, `Ref`, and promise adapters where they improve lifecycle clarity.
- Long-lived resources still start from `session_start` or the command/tool/event that needs them, never from extension factory scope.

## Component Boundaries

### Shared foundation

The shared foundation is responsible for package setup and small reusable adapters only. It must not become a framework. Add shared helpers only when at least two extensions need the same adapter pattern.

Possible shared helpers:

- `runEffectHandler`: adapt an Effect program to a Pi async callback.
- `runSyncEffect`: adapt a pure/synchronous Effect program to a Pi render or decision function.
- small error-to-string helpers for tests and UI notifications.

### `attention-hooks`

Keep the existing public behavior:

- play completion sound on eligible `agent_end`
- play attention sound on `subagent:control-event` with type `needs_attention`
- suppress sounds in subagent child processes
- avoid duplicate event-bus subscriptions across reloads
- ignore missing sound files and spawn failures

Effect conversion:

- Represent sound path lookup, file existence, and `afplay` spawn as Effect programs.
- Represent control-event and agent-end decisions as Effect-returning functions, with synchronous wrappers for existing tests where needed.
- Preserve the global unsubscribe store and make replacement cleanup explicit.

### `custom-footer`

Keep the existing public behavior:

- custom footer replaces the built-in footer in UI sessions
- rate limits refresh on session start, turn end, interval, and manual command
- minimum refresh gap, in-flight dedupe, stale status, warning debounce, exponential backoff, and wake-delay behavior remain unchanged
- footer rendering remains synchronous and returns exact existing strings
- Codex app-server JSON-RPC interaction preserves timeout, stderr detail, request ordering, and child cleanup

Effect conversion:

- Convert rate-limit parsing and formatting internals to Effect/Option/Either style while preserving exported compatibility wrappers where needed by existing callers.
- Convert refresh state to explicit Effect-managed state, using `Ref` where it improves clarity.
- Convert refresh execution into Effect programs that return the same status transitions as today.
- Convert Codex JSON-RPC subprocess handling into a dedicated Effect program with explicit acquire/release cleanup.
- Keep render functions synchronous by running pure Effect programs with `Effect.runSync` at the Pi render boundary.

### `history-picker`

Keep the existing public behavior:

- Ctrl-R opens the history picker only in interactive TUI mode
- non-TUI mode notifies when UI is available and does not index sessions
- initial query comes from editor text
- current and saved session messages are indexed and searched
- saved-session refresh is start-or-join and listener-based
- selected prompt is trimmed before being placed into the editor
- refresh listeners unsubscribe when the picker closes
- `HistoryPickerComponent` remains compatible with Pi TUI `Component` and `Focusable` expectations

Effect conversion:

- Convert session listing, stat, read-file, JSONL parsing, cache updates, and listener updates to Effect programs.
- Convert search, dedupe, scoring, and state transitions to Effect-first functions with sync wrappers for render and key handling.
- Keep `HistoryPickerComponent` methods synchronous because Pi TUI expects synchronous `render` and input handling.
- Convert `openHistoryPicker` into an async Pi boundary that runs the Effect program and performs UI side effects in the same order as today.

## Testing Design

Testing will move to Node + Vitest + `@effect/vitest`.

Primary command:

```bash
cd modules/home-manager/programs/pi/extensions
env -u PI_SUBAGENT_CHILD node --run test
```

Expected `package.json` script:

```json
{
  "scripts": {
    "test": "vitest run"
  }
}
```

Test migration rules:

- Replace `bun:test` imports with Vitest or `@effect/vitest` imports.
- Use `@effect/vitest` for Effect-native tests.
- Use `it.effect(...)` for ordinary Effect programs.
- Use `it.scoped(...)` for scoped resource tests.
- Use Vitest `vi` mocks instead of Bun `mock`.
- Keep existing behavioral assertions intact.
- Do not add dedicated dependency/runtime smoke tests for the shared `effect` dependency.

Behavior that must remain covered:

- attention-hooks sound suppression and playback best-effort behavior
- no duplicate attention event subscriptions across reloads
- custom-footer pending, success, stale, backoff, manual refresh, and wake-delay behavior
- custom-footer exact footer/status strings
- Codex JSON-RPC parse/error/timeout/cleanup behavior where currently covered or where conversion adds a new seam
- history-picker non-TUI guard, overlay options, selected prompt trimming, session index cache reuse, parse failures, listener updates, search ordering, and width constraints

## Validation Design

Run targeted validation after each milestone:

```bash
cd modules/home-manager/programs/pi/extensions
env -u PI_SUBAGENT_CHILD node --run test
```

If Home Manager wiring changes, additionally run the passing targeted home evals identified during reconnaissance:

```bash
nix eval --raw .#homeConfigurations.ddd-complyance.activationPackage.drvPath
nix eval --raw .#homeConfigurations.abra.activationPackage.drvPath
```

Do not fix unrelated known Nix failures in this work. If they still appear, document them as pre-existing and out of scope.

## Execution Plan Shape

Implementation should proceed in milestones:

1. Dependency and test-runner migration
2. `attention-hooks` Effect pilot
3. `custom-footer` helper and refresh conversion
4. `custom-footer` Codex JSON-RPC conversion
5. `history-picker` Effect conversion
6. Final review and cleanup

Use a single-writer flow:

- One writer modifies the active worktree at a time.
- Read-only subagents may scout, review, or validate.
- Fresh-context reviewers inspect the diff after major milestones.
- A final writer applies accepted review fixes.

Every milestone must report:

- changed files
- tests added or updated
- commands run
- validation output
- residual risks

## Risks and Mitigations

### Symlink/package resolution risk

Home Manager currently symlinks each extension directory individually. The shared parent package may not be visible through all runtime resolution paths. This design intentionally skips dedicated runtime smoke coverage by request, so implementation must rely on normal Node/Vitest tests and Pi runtime behavior observed during normal use.

Mitigation: keep dependency plumbing minimal and avoid unrelated Home Manager changes. If normal test execution cannot resolve dependencies, adjust package placement or Home Manager wiring only enough to make the shared package visible.

### Bun-to-Vitest migration risk

Existing tests rely on Bun's `mock` API and ambient package resolution. Vitest has different mocking semantics.

Mitigation: migrate tests first as a standalone milestone before changing extension internals.

### Effect over-conversion risk

Full internal Effect style can reduce readability if every trivial expression becomes a noisy Effect pipeline.

Mitigation: use Effect as the primary internal model while allowing type guards, constants, and Pi-required synchronous adapters to stay simple.

### Custom-footer subprocess risk

The Codex app-server path is the highest-risk IO path because it involves subprocess lifecycle, JSON-RPC sequencing, timeout, stderr capture, and safehouse/keychain assumptions.

Mitigation: convert it as its own milestone after the test runner and simpler Effect conversions are stable.

### TUI synchronous boundary risk

Pi TUI render and input methods expect synchronous behavior.

Mitigation: keep TUI class methods synchronous and use `Effect.runSync` only for pure internal computations at those boundaries.

## Acceptance Criteria

- The three repo-managed extensions are converted to Effect-first internals.
- Existing Pi extension entrypoints and user-visible behavior are preserved.
- Tests run with Node + Vitest + `@effect/vitest` via `env -u PI_SUBAGENT_CHILD node --run test` from `modules/home-manager/programs/pi/extensions`.
- The migrated test suite passes.
- No dedicated dependency/runtime smoke test for `effect` is added.
- No third-party Pi packages or unrelated Nix configuration are changed.
- Cleanup behavior is preserved for timers, footer disposals, event-bus unsubscribes, refresh listeners, and child processes.
