# Repository hygiene — worktrees

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-REPO-002

## Decision

Agent / Claude worktrees must **never** be committed as gitlinks (`mode 160000`).

- `.claude/` is gitignored (entire tree).
- `.worktrees/` is gitignored.
- Contributors must not `git add` worktree directories or submodule-style links under those paths.

## Verification

- `git ls-files -s` must not list any `160000` entries for worktrees.
- Contract test asserts `.gitignore` covers `.claude/` and `.worktrees/`.

## `.codex/` (Z-REPO-003)

`.codex/` is listed in `.gitignore`. Speckit prompt stubs under `.codex/prompts/` may
still be tracked intentionally for contributor onboarding — do **not** commit
`.codex/logs*`, SQLite WAL, or model caches. Prefer `git status` before commit;
untrack accidental lockfiles with `git rm --cached`.
