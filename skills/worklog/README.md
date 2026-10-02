# worklog

Capture the week's accomplishments as they happen, then produce a clean, impact-focused
summary email at the end of the week — drafted in your voice.

## What it does

- **Log entries** on demand ("add to my worklog: shipped X") or when an AI session wraps up.
- **Stores one Markdown file per ISO week** at `$WORKLOG_DIR/<ISO-year>-W<week>.md` (default
  `~/worklog/`), with each day as a section inside.
- **Keeps notes impact-first** — value and outcome over exhaustive task lists; low-signal work
  is skipped.
- **Generates a weekly email** from [`templates/weekly-email.md`](templates/weekly-email.md) for a
  **manager or director**: related log bullets collapse into 1–2 impact lines per project,
  implementation detail stays in the log, written in your voice via
  [`write-like-me`](../write-like-me).

## Usage

Just ask, in natural language:

- `add to my worklog: cut the ETL runtime from 40m to 8m, unblocks same-day finance reporting`
- `log what we got done this session`
- `write my weekly worklog summary` / `what did I accomplish this week?`

## Storage

```
$WORKLOG_DIR/      # default: ~/worklog/
  2026-W31.md      # days are ## sections inside
  2026-W32.md
```

Defaults to `~/worklog`. Point it somewhere else with the `WORKLOG_DIR` env var — e.g. a synced
folder so the log follows you between machines:

```bash
export WORKLOG_DIR="$HOME/Documents/worklog"
```

Set it in `dotfiles/.zshrc.local` (machine-specific) or `dotfiles/.zshrc` (shared). Use an absolute
path or `$HOME/...` rather than a bare `~`. The directory is created on first write.

Wherever it points, this is personal data living outside the dotfiles repo — never commit it here.

## Weekly email template

[`templates/weekly-email.md`](templates/weekly-email.md) is the skeleton for that manager-facing
email (headline, 1–2 bullets per project, in-flight / blockers / next week only when useful). Daily
log notes (honest reads, scoring) inform the draft but are not copied in. Wording comes from
`write-like-me` using the leadership register, with jargon stripped. Edit the template to change
the shape.

## Installation

```bash
npx skills add ./skills/worklog
```

Uses `write-like-me` for the summary email's voice. If that profile isn't built yet, the summary
falls back to plain professional prose.
