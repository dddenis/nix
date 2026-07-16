---
description: Write and commit an implementation plan in a spec's existing worktree
argument-hint: "<spec-path>"
---
Write an implementation plan for the specification at `$1`.

Before modifying anything:

1. Require a non-empty specification path. Treat it as relative to a Git
   worktree root.
2. Confirm the current directory belongs to a Git repository.
3. Parse `git worktree list --porcelain`. For every `worktree` entry, check
   whether `$1` exists as a file beneath that worktree root.
4. Continue only if exactly one worktree contains the specification. If none
   or more than one match, stop and report the candidates.
   Do not create a worktree.
5. Inspect that worktree's status. Stop if the plan cannot be committed
   without including unrelated changes.

Use the matching worktree root as the working directory for every subsequent
file and Git operation. Invoke the `writing-plans` skill and follow it to write
the implementation plan from `$1`. Do not implement the plan.

When the plan is complete, self-review it as required by the skill, inspect the
diff, and run applicable documentation checks if the repository provides any.
Stage only the generated plan and verify the staged diff contains no unrelated
changes. Commit it in the matching worktree with a conventional commit message.
Report the worktree path, plan path, verification performed, and commit hash.
