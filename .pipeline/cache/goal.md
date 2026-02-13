## Objective

Replace CLAUDE.md with a symlink that points to AGENTS.md, so both files always share the same content.

## Reference

- CLAUDE.md — Current standalone file to be replaced with symlink
- AGENTS.md — Target file the symlink should point to

## Outcomes

- CLAUDE.md is a symlink pointing to AGENTS.md
- The symlink uses a relative path (AGENTS.md, not an absolute path)
- No content is lost (AGENTS.md remains unchanged)

## Acceptance

- `readlink CLAUDE.md` outputs `AGENTS.md`
- `test -L CLAUDE.md` succeeds (confirms it's a symlink)
- `diff CLAUDE.md AGENTS.md` shows no differences