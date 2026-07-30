---
name: worklog
description: |
  Captures accomplishments, impact, and notable work throughout the week, then produces a clean
  end-of-week summary email. Use this skill when the user asks to:
  - Log / add / capture something they worked on or accomplished ("add to my worklog", "log this win",
    "remember I shipped X", "note that I...")
  - Wrap up an AI session by recording what got done
  - Produce the weekly summary / email of accomplishments ("worklog summary", "write my weekly update",
    "what did I get done this week")
  Notes are impact-first (value/outcome over task lists), one Markdown file per ISO week under
  ~/worklog/. The weekly email is drafted in the user's voice via the write-like-me skill.
---

# Worklog

Capture the week's accomplishments as they happen, then synthesize a concise, impact-focused summary
email at week's end. The store is the source of truth; every entry lives in a dated Markdown file.

## Storage layout

```
~/worklog/
  <ISO-year>-W<ISO-week>.md     e.g. 2026-W31.md   (one file per week; days are headers inside)
```

Compute the path with the shell — never guess:
- This week's file: `FILE=~/worklog/$(date +%G-W%V).md; echo $FILE`
- Today's day header: `date +"%Y-%m-%d (%a)"` → `2026-07-30 (Thu)`
- macOS `date` supports `%G` (ISO year) and `%V` (ISO week). Monday starts the week.

Create `~/worklog/` with `mkdir -p` before writing. The tree is outside this repo — it is personal
data, never commit it here.

## What makes a good entry

**Focus on value and impact, not an exhaustive task list.** Each entry should answer "so what?"

- ✅ "Cut nightly ETL runtime 40min→8min by batching the S3 reads — unblocks same-day reporting for finance."
- ✅ "Led the auth migration design review; team aligned on the phased cutover, de-risking the Q3 launch."
- ❌ "Attended standup, replied to emails, updated a ticket." → low value, skip it.
- ❌ "Changed a variable name, fixed a typo." → skip unless it mattered.

Rules:
- Prefer outcome + who benefited over the mechanics of the task.
- One line per accomplishment. A short parenthetical for impact is fine.
- Skip routine/low-signal activity. When unsure whether it belongs, ask "would this matter in a
  manager update?" — if no, drop it.
- Keep it concise. A day rarely needs more than 3–5 bullets.

## Weekly file format

One file per week; each day is a `##` section, appended as the week progresses.

```markdown
# Worklog — 2026-W31

## 2026-07-30 (Thu)

- **[area]** Accomplishment framed by impact. (why it mattered)
- **[area]** ...

## 2026-07-31 (Fri)

- **[area]** ...
```

`[area]` is an optional short tag (project, system, initiative) to make weekly grouping easy. Omit if
it adds noise.

## Workflow: adding an entry

Trigger: user asks to log/add/note something, or an AI session is wrapping up.

1. **Resolve this week's file** with the `date` command above; `mkdir -p ~/worklog`.
2. **Distill the accomplishment to impact.** If the user hands you a raw task, reframe it around value
   and outcome before writing. Drop it entirely if it's low-signal (tell them you skipped it and why).
3. **Append**, don't overwrite. If the file is new, add the `# Worklog — <ISO-week>` title. If today's
   `## <date> (<Day>)` section doesn't exist yet, add it; then append the bullet(s) under today's
   section. Never disturb earlier days.
4. **Confirm** in one line what you logged and where.

### End-of-session capture

When a working session ends (or the user says "log what we did"), scan the session for genuine
accomplishments — things shipped, unblocked, decided, designed, fixed with real impact. Propose 1–3
impact-framed bullets and ask before writing (don't log churn or exploration that led nowhere).

## Workflow: weekly summary email

Trigger: "worklog summary", "weekly update", "what did I do this week", end of week.

1. **Gather the week.** Default to the current week file; honor an explicit week if asked.
   `cat ~/worklog/$(date +%G-W%V).md` (or the requested week). If missing/empty, say so and offer to
   backfill from recent sessions.
2. **Synthesize, don't transcribe.** Merge related bullets, group by theme/project (`[area]` tags
   help), lead with the highest-impact items. Cut anything low-value that slipped in. Aim for a
   tight email — a handful of themed highlights, not a daily replay.
3. **Draft in the user's voice.** Invoke the **write-like-me** skill to write the email so it sounds
   like the user. Pass it the synthesized highlights as the content and "weekly accomplishments email"
   as the ask. If write-like-me's profile is unbuilt, fall back to a clean, plain professional summary
   and note that.
4. **Return the email** as an editable block (subject + body). Offer to also save it, but don't send
   anything — the user sends it themselves.

## Notes

- The daily notes are terse by nature; the **summary email is normal prose** (via write-like-me) — it
  is exempt from any compressed/terse output mode.
- Never invent accomplishments. If the week's files are thin, the summary is thin — offer to backfill,
  don't pad.
