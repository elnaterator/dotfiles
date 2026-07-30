# worklog

Capture the week's accomplishments as they happen, then produce a clean, impact-focused
summary email at the end of the week — drafted in your voice.

## What it does

- **Log entries** on demand ("add to my worklog: shipped X") or when an AI session wraps up.
- **Stores one Markdown file per ISO week** at `~/worklog/<ISO-year>-W<week>.md`, with each day
  as a section inside.
- **Keeps notes impact-first** — value and outcome over exhaustive task lists; low-signal work
  is skipped.
- **Generates a weekly email** that synthesizes and themes the week's entries, written in your
  voice via the [`write-like-me`](../write-like-me) skill.

## Usage

Just ask, in natural language:

- `add to my worklog: cut the ETL runtime from 40m to 8m, unblocks same-day finance reporting`
- `log what we got done this session`
- `write my weekly worklog summary` / `what did I accomplish this week?`

## Storage

```
~/worklog/
  2026-W31.md      # days are ## sections inside
  2026-W32.md
```

This lives in your home dir, outside the dotfiles repo — it's personal data and is never committed.

## Installation

```bash
npx skills add ./skills/worklog
```

Uses `write-like-me` for the summary email's voice. If that profile isn't built yet, the summary
falls back to plain professional prose.
