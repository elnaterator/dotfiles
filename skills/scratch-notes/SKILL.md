---
name: scratch-notes
description: |
  Appends quick, concise scratch notes to one centralized notes file. Use this skill when the
  user asks to:
  - Jot / scratch / note something down ("jot this down", "scratch note", "note to self",
    "add to my notes", "take a note", "save this thought")
  - Capture a quick idea, reminder, command, link, or finding for later
  - Dump short context from the current session into their notes
  Notes are terse bullet points appended to $SCRATCH_NOTES_FILE (default ~/notes.md), each new
  entry separated by `---`. Not for accomplishments/impact tracking — that's the worklog skill.
---

# Scratch Notes

Fast capture to one flat file. Append-only, newest at the bottom, every entry separated by `---`.
No organizing, no rewriting old entries, no ceremony.

## Storage

The notes file is `$SCRATCH_NOTES_FILE`, defaulting to `~/notes.md` when unset or empty.

Resolve the path with the shell — never guess, never hardcode `~/notes.md`:

```bash
FILE="${SCRATCH_NOTES_FILE:-$HOME/notes.md}"; FILE="${FILE/#\~/$HOME}"; echo "$FILE"
```

Notes on `$SCRATCH_NOTES_FILE`:
- Always quote it — the path may contain spaces.
- `~` in the value is not shell-expanded when read from a variable; expand it yourself as above.
- The user sets it in their shell config, e.g. `export SCRATCH_NOTES_FILE="$HOME/Documents/notes.md"`.
- If the parent directory doesn't exist, create it (`mkdir -p`) rather than falling back to the
  default — silently writing elsewhere loses notes.

The file is personal data outside this repo — never commit it here.

## Note style

Concise. Bullet points. Caveman compression when a caveman mode is active (drop articles/filler,
fragments fine) — but keep all technical substance exact: commands, paths, URLs, error strings,
names, numbers verbatim.

- ✅ `- fix flaky auth test: mock clock, not sleep`
- ✅ `- subnet-ips slow on big VPCs — cache describe-network-interfaces?`
- ❌ A paragraph restating the whole conversation.
- ❌ Headers, tables, nested outlines — this is a scratch pad, not a doc.

Rules:
- 1–5 bullets per entry. Distill; don't transcribe.
- Optional one-line `**topic**` bold lead if the bullets need context.
- Start each entry with the date: `**YYYY-MM-DD**` (get it via `date +%F`).
- Preserve code/commands/URLs exactly, in backticks.

## Entry format

Each append produces:

```markdown
---

**2026-08-24** optional topic

- first point
- second point
```

The `---` separator goes *before* the new entry (the script handles this — it skips the separator
when the file is new/empty).

## Workflow: adding a note

1. **Distill** what the user gave you into 1–5 terse bullets (style above). Confirm nothing — just
   capture. If the ask is vague ("note this"), note the immediately preceding subject.
2. **Append** — prefer the helper script (handles path resolution, separator, mkdir):

   ```bash
   ~/.dotfiles/skills/scratch-notes/scripts/append-note.sh "**$(date +%F)** topic" "- point one" "- point two"
   ```

   Or pipe multi-line content via stdin:

   ```bash
   printf '%s\n' "**$(date +%F)** topic" "" "- point one" "- point two" | ~/.dotfiles/skills/scratch-notes/scripts/append-note.sh
   ```

   Use the script whenever direct file-write tools can't reach the notes file (outside allowed
   write paths, sandboxed session, etc.). If you *do* have direct write access, appending with the
   file-edit tool is fine — replicate the same format: leading `---` separator (unless file is
   new/empty), blank lines around it, dated entry.
3. **Confirm** in one line: what was noted and the file path.

## Workflow: reading notes back

If asked "what's in my notes" / "find that note about X": `cat`/grep the resolved file. Read-only —
never rewrite or reorganize past entries unless explicitly asked.
