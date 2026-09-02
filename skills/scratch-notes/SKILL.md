---
name: scratch-notes
description: |
  Appends quick, terse scratch notes to one centralized notes file. Use when the user asks to:
  - Jot / scratch / note something down ("jot this down", "scratch note", "note to self",
    "add to my notes", "take a note", "save this thought")
  - Capture a quick idea, reminder, command, link, or finding for later
  - Dump short context from the current session into their notes
  Notes go to $SCRATCH_NOTES_FILE (default ~/notes.md), entries separated by `---`.
  Not for accomplishments/impact tracking — that's the worklog skill.
---

# Scratch Notes

Append-only flat file. Newest at bottom. No organizing, no rewriting old entries.

## Add a note

1. **Distill** into 1–5 terse bullets. Confirm nothing — just capture. Vague ask ("note this")
   = note preceding subject.
2. **Append** via script — it resolves `$SCRATCH_NOTES_FILE`, expands `~`, does `mkdir -p`, and
   writes the `---` separator (skipped when file new/empty). Empty-string arg = blank line:

   ```bash
   ~/.dotfiles/skills/scratch-notes/scripts/append-note.sh "**$(date +%F)** topic" "" "- point one" "- point two"
   ```

   Multi-line via stdin also works: `printf '%s\n' ... | append-note.sh`.
   Always use the script — direct file writes miss the path resolution and separator logic.
3. **Confirm** one line: what noted + file path.

Resulting entry:

```markdown
---

**2026-08-24** optional topic

- first point
- second point
```

## Style

Terse bullets. Caveman compression when a caveman mode active. Technical substance exact —
commands, paths, URLs, error strings, names, numbers verbatim, in backticks.

- ✅ `- fix flaky auth test: mock clock, not sleep`
- ✅ `- subnet-ips slow on big VPCs — cache describe-network-interfaces?`
- ❌ Paragraph restating conversation.
- ❌ Headers, tables, nested outlines — scratch pad, not doc.

Bold `**topic**` lead optional, only if bullets need context. Date line always `**YYYY-MM-DD**`.

## Read back

"What's in my notes" / "find note about X" → `cat`/grep resolved path:

```bash
FILE="${SCRATCH_NOTES_FILE:-$HOME/notes.md}"; FILE="${FILE/#\~/$HOME}"; grep -n "X" "$FILE"
```

Read-only. Never rewrite or reorganize past entries unless explicitly asked.

## Sandbox blocks write

Append fails `/path/to/notes.md: Operation not permitted` when notes file outside sandbox
allowlist. Do **not** retry, fall back to `~/notes.md`, or write elsewhere — loses notes silently.

Tell user to add notes file's **parent directory** (not the file — append rewrites it, needs
directory write) to `sandbox.filesystem.allowWrite` in `~/.claude/settings.json`, snippet filled
with their resolved path:

```json
{
  "sandbox": {
    "filesystem": {
      "allowWrite": ["/Users/you/path/to/notes-dir"]
    }
  }
}
```

Merge into existing `sandbox` block, don't replace. `~` and `./output` paths OK. New session to
take effect. Then offer re-append. If they decline settings change, hand them the one-line
`append-note.sh` command for their own terminal.

Notes file is personal data outside this repo — never commit it here.
