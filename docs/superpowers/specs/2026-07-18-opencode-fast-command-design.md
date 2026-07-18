# OpenCode Fast Command Design

## Goal

Provide a global OpenCode `/fast` command with the same behavior as the
existing Pi `fast` prompt managed by this repository.

## Design

Add a dedicated `ddd.programs.opencode` Home Manager module following the
existing Pi module structure. When enabled, it links the repository's OpenCode
command directory to `~/.config/opencode/command`, making `/fast` available in
all projects. Import the module from the programs module index and enable it in
the shared profile.

The `fast.md` command retains the Pi prompt's description and instructions.
Pi-only `argument-hint` metadata is omitted, and Pi's `$@` argument placeholder
is translated to OpenCode's `$ARGUMENTS` placeholder.

## Verification

Run the repository's focused Nix formatting/evaluation checks and inspect the
diff to confirm that the module is imported, enabled, and points at the command
directory. Confirm the command file uses only supported OpenCode frontmatter
and argument syntax.
