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
  $WORKLOG_DIR (default ~/worklog/). The weekly email is a manager/director status update: translated
  out of engineer-log detail, consolidated per project, drafted in the user's voice via write-like-me.
---

# Worklog

Capture the week's accomplishments as they happen, then synthesize a concise manager/director
status email at week's end. The store is the source of truth; every entry lives in a dated Markdown
file. Daily bullets may stay technical; the email is a translation for someone who is not intimate
with the implementation.

## Storage layout

The worklog root is `$WORKLOG_DIR`, defaulting to `~/worklog` when the variable is unset or empty.

```
$WORKLOG_DIR/                   default: ~/worklog/
  <ISO-year>-W<ISO-week>.md     e.g. 2026-W31.md   (one file per week; days are headers inside)
```

Compute the path with the shell — never guess, and never hardcode `~/worklog`:
- Root: `WORKLOG_DIR="${WORKLOG_DIR:-$HOME/worklog}"; echo "$WORKLOG_DIR"`
- This week's file: `FILE="${WORKLOG_DIR:-$HOME/worklog}/$(date +%G-W%V).md"; echo "$FILE"`
- Today's day header: `date +"%Y-%m-%d (%a)"` → `2026-07-30 (Thu)`
- macOS `date` supports `%G` (ISO year) and `%V` (ISO week). Monday starts the week.

Notes on `$WORKLOG_DIR`:
- Always quote it — the path may contain spaces (e.g. an iCloud or OneDrive folder).
- `~` inside the value is not expanded by the shell when it comes from a variable. If the value
  starts with `~/`, expand it yourself: `WORKLOG_DIR="${WORKLOG_DIR/#\~/$HOME}"`.
- The user sets it in their shell config, e.g. `export WORKLOG_DIR="$HOME/Documents/worklog"`.
- If the variable points somewhere that doesn't exist, create it (`mkdir -p`) rather than falling
  back to the default — silently writing elsewhere loses entries.

Create the root with `mkdir -p "$WORKLOG_DIR"` before writing. The tree is outside this repo — it is
personal data, never commit it here.

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

1. **Resolve this week's file** with the `date` command above; `mkdir -p "${WORKLOG_DIR:-$HOME/worklog}"`.
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

**Audience is always a manager or director.** They know the products and teams at a high level
(CW2SNOW, MWatch, Harness, which org owns support). They are not intimate with the implementation.
If they would need a PR, wiki page, or error code to understand a sentence, cut it. Do not produce
a technical recap unless the user explicitly asks for one.

Daily log bullets stay technical — that is for the user. The email is a **translation**, not a
shortened copy of those bullets.

1. **Gather the week.** Default to the current week file; honor an explicit week if asked.
   `cat "${WORKLOG_DIR:-$HOME/worklog}/$(date +%G-W%V).md"` (or the requested week). If
   missing/empty, say so and offer to backfill from recent sessions.
   Read the **whole file**: day bullets *and* any extra notes (honest reads, goal scoring, patterns,
   "where we are" asides). Use those notes as background so the draft is accurate. **Do not paste
   them into the email** — no self-critique, Rock slips, evidence holes, or vault wiki links.
2. **Translate, then consolidate.** Group by `[area]` / project. Related work is the same app
   **and** the same kind of result (handoff, reliability, security, shipping, unblocking a team).
   For each group write **one impact statement**; a **second bullet only** if the outcomes are
   genuinely different (e.g. "support now sits with Cloud Engineering" vs "scanner in CI can
   actually authenticate"). Aim for **1–2 tight bullets per project**, **2–4 projects** total.
   Lead with the highest-impact theme. Cut low-value items that slipped into the log.
3. **Fill the template.** Read `templates/weekly-email.md` (next to this SKILL.md) and map the
   synthesized themes onto it. The template is the structure, not the wording — drop sections that
   have no content rather than padding them.
4. **Draft in the user's voice.** Invoke the **write-like-me** skill. Pass: the filled template as
   content; ask = **weekly status email to manager/director**; register = **Email — leadership /
   wide / directors**. Tell it to keep warmth and diplomacy but **strip implementation jargon**
   even if the profile is comfortable with domain terms. Voice wins over the template's phrasing;
   audience and consolidation win over the profile's "technically precise" habit. If
   write-like-me's profile is unbuilt, fall back to a clean, plain professional summary and note that.
5. **Return the email** as an editable block (subject + body). Offer to also save it, but don't send
   anything — the user sends it themselves.

### Translation rules (email only)

Answer, in the reader's vocabulary: **what landed**, **who it helps or what changed in operations**.
Add **where we are** (done, waiting on X, design only) **only when that is not obvious** from the
outcome. "Shipped to prod" does not need a status clause. "Wrote the design; implementation has not
started" does.

**Drop by default:** PR numbers, ticket keys, CLI flags, error codes, file/stage/template names,
commit mechanics, roadmap item IDs, wiki `[[links]]`. Keep a ticket or name only if the reader
already tracks that item (a handoff they asked about, a team they know). Keep product names; gloss
once if needed ("CW2SNOW (CloudWatch alerts into ServiceNow)").

**Human cadence, not an impact formula.** Short sentences, one idea each. Lead with the outcome,
not the work. Use I / we / they and ordinary time ("this week", "next week"). Do not stack
"accomplishment — mechanism — unblocks Y — de-risking Z." Avoid machine tells: *unblocks*,
*de-risking*, *closes the last operational dependency*, *minimum standard*, *false-green*,
*merge gate*.

❌ "Finished the ownership handoff end to end: updated every DL and ownership record (FEDP-308).
Closes the last operational dependency on Goal 5's minimum standard, so an alert at 2am reaches
their rota rather than Nathan's."
✅ "Finished the CW2SNOW support handoff. Overnight alerts now go to FSD Cloud Engineering's rota,
not to me."

❌ Five bullets: tflint installer, tofu cache, Checkmarx creds, pipeline restore, memory ceiling.
✅ "Kept the CW2SNOW pipeline honest this week — builds stay red when a scanner can't run, and we
fixed the breakage that was taking CI down."

## Notes

- Daily entries can stay technical and long; the **summary email is normal prose** for a manager
  (via write-like-me) — it is exempt from any compressed/terse output mode.
- Never invent accomplishments. Extra notes in the week file may sharpen wording or "where we
  are"; they are not a license to add work that isn't in the bullets. Thin week → short email;
  offer to backfill, don't pad.
