# jira

Lets Claude Code work Jira tickets through the [`jira` CLI](https://github.com/ankitpokhrel/jira-cli)
without ever opening its interactive TUI. Scope is intentionally small: the read/write verbs a
developer uses daily.

## What it covers

- **My issues table:** `scripts/my-issues.sh` prints your open issues as a Markdown table with
  linked keys, status, priority, epic, sprint name, and sprint state (active / future / closed /
  none). It defaults to your **active sprints only**; pass `--all` for the backlog and closed
  sprints. The skill uses it for any "my issues" / "what's on my plate" request so the answer
  always has the same shape.
- **Story points:** `scripts/set-story-points.sh KEY N` sets **Story Points** over the REST
  API and verifies the write, because `jira issue edit --custom "Story Points=N"` silently
  no-ops on Jira Data Center. The field id is resolved by name from the jira-cli config
  (`JIRA_STORY_POINTS_FIELD` overrides the name). The script reads `JIRA_API_TOKEN` itself so
  the token never reaches a command line or a transcript.
- **Read:** my issues, current/prev/next sprint, free-text and JQL search, single issue with
  comments, epics, raw JSON for `jq`.
- **Write:** create, edit, transition, assign, comment, link, add to epic and sprint, log work,
  watch. Newly created issues are always self-assigned and always placed under an epic (the
  skill asks which one when it is not obvious).
- **Setup check:** verifies auth with `jira me` and explains the fix when the token is missing.

Every command in the skill carries the flags that make `jira` non-interactive (`--plain`,
`--raw`, `--no-input`, `--no-browser`). See [SKILL.md](SKILL.md) for the full command sheet.

## Prerequisites

1. Install the CLI:

   ```bash
   brew install jira-cli
   ```

2. Configure it once (interactive is fine here, it is a one-off in your own terminal):

   ```bash
   jira init
   ```

3. Make the token visible to Claude Code. Claude Code does not load shell rc files, so a
   `JIRA_API_TOKEN` exported in `.zshrc` is invisible to it. Add it to `~/.claude/settings.json`:

   ```json
   {
     "env": {
       "JIRA_API_TOKEN": "your-token",
       "JIRA_AUTH_TYPE": "bearer"
     }
   }
   ```

   `JIRA_AUTH_TYPE=bearer` is for Data Center / Server Personal Access Tokens. Omit it for
   Atlassian Cloud API tokens (basic auth). If this site does not call the estimate field
   `Story Points`, add `JIRA_STORY_POINTS_FIELD` with the exact name from Jira (and declare
   that field under `issue.fields.custom` in the jira-cli config). Start a new Claude Code
   session after editing.

## Install the skill

From the repo root:

```bash
npx skills add ./skills/jira
```

## Usage

Natural language is enough:

- `what's on my plate in jira`
- `show me PROJ-123 with the last few comments`
- `move PROJ-123 to In Review and assign it to me`
- `create a bug in PROJ: login page 500s on empty password`
- `comment on PROJ-123: fixed in #482, ready for QA`
- `find open high-priority bugs updated this week`
