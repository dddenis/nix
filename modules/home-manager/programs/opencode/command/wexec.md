---
description: Execute a committed implementation plan in its existing worktree with subagents
agent: build
---
Execute the implementation plan at `$1` using subagent-driven development.

Before modifying anything:

1. Require a non-empty plan path. Treat it as relative to a Git worktree root.
2. Confirm the current directory belongs to a Git repository.
3. Parse `git worktree list --porcelain`. For every `worktree` entry, check
   whether `$1` exists as a file beneath that worktree root.
4. Continue only if exactly one worktree contains the plan. If none or more
   than one match, stop and report the candidates.
5. Verify the plan is tracked, committed, and unchanged in that worktree.
   Stop if it is not the committed output expected from `/wplan`.
6. Verify the matching worktree is on a non-main branch. Do not create another
   worktree, switch branches, or move or copy the plan.
7. Inspect the worktree status. If existing changes are not part of a coherent,
   resumable subagent-driven-development run, stop and report them rather than
   risking unrelated work.

Use the matching worktree root as the working directory for every subsequent
file, Git, and tool operation.

Invoke the `subagent-driven-development` skill and follow it exactly to execute
the complete plan in this session. Do not re-brainstorm, rewrite the plan, or
substitute the `executing-plans` workflow. Perform the skill's pre-flight plan
review, resume from its durable progress ledger when applicable, and continue
through every task, review loop, final review, and branch-finishing workflow.
Do not pause between tasks; stop only when the skill requires human input, an
unresolved blocker prevents progress, or the workflow is complete.

Report the worktree path, plan path, completed tasks and commits, verification
performed, and final branch state or blocker.
