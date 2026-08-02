---
name: fast
description: Use when the user explicitly invokes $fast with a small, well-scoped task whose requirements are already clear.
---

# Fast

Treat the remainder of the invoking user message, excluding the `$fast`
mention, as the task. If it is empty, ask for the task and stop.

For this request only, explicitly override and skip Superpowers'
brainstorming, design/planning, worktree, subagent, formal-review, and
branch-finishing workflows.

Make the smallest targeted change directly. Inspect only the context needed
for the change, run focused tests or checks, and report the result. Do not
commit unless the user explicitly asks.

Higher-priority system, developer, safety, and repository instructions still
apply. If the task is ambiguous, risky, or no longer small and well-scoped,
pause and explain what must be resolved before expanding the work.

## Example

```text
$fast Fix the typo in README.md and run the Markdown check.
```
