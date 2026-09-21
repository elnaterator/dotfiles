---
name: jira
description: |
  Day-to-day Jira work through the `jira` CLI (ankitpokhrel/jira-cli), run non-interactively.
  Use when the user asks to:
  - See their tickets / sprint / backlog ("what's on my plate", "my open issues", "current sprint")
  - Look up or search issues ("show PROJ-123", "find tickets about X", any JQL)
  - Create, edit, comment on, assign, or transition an issue ("move PROJ-123 to In Progress",
    "create a bug for...", "comment on PROJ-123")
  - Log work or link issues
  Also triggers on any bare issue key like PROJ-123 in a request about its status or contents.
---

# Jira CLI

Drive `jira` (https://github.com/ankitpokhrel/jira-cli) from a shell. It is built for
interactive TUI use, so **every command here forces non-interactive mode**. Never run a bare
`jira issue list`, `jira sprint list`, `jira epic list`, or `jira issue create` without the
flags below: they open a TUI or a prompt and hang the session.

## Rules

1. **Reads:** always `--plain` (tables) or `--raw` (JSON). Add `--no-headers` when piping,
   `--columns` to trim, `--paginate 0:N` to cap results (max 100 per page).
2. **Writes:** always `--no-input`, and pass every field via flags. Never rely on prompts.
3. **Self:** `$(jira me)` yields the configured user's login/email. Use it for "my" filters and
   self-assign.
4. **Project:** commands default to the project in `~/.config/.jira/.config.yml`. Add `-pKEY`
   for another project.
5. **Confirm before destructive or noisy actions:** `issue delete`, bulk edits, transitions
   with `--resolution`, anything touching more than one issue. Reads, single comments, and
   single-issue edits the user explicitly asked for need no confirmation.
6. Show the user the key and URL of anything you create or change. `jira open KEY --no-browser`
   prints the URL without launching a browser.
7. **Every new issue is assigned to the user and lives under an epic.** See below; this is not
   optional and applies even when the request only says "create a story for X".

## Auth and setup check

Run once per session before the first real command:

```bash
jira me
```

- Prints a login/email: good.
- `The tool needs a Jira API token to function.`: `JIRA_API_TOKEN` is not in the environment.
  Claude Code does not load shell rc files. Tell the user to add it to `~/.claude/settings.json`
  under `"env"` (and `JIRA_AUTH_TYPE=bearer` if their server uses a Personal Access Token),
  then start a new session. Do not ask for the token value and do not put it in a command.
- `config file not found` or similar: run init non-interactively (values from the user):

  ```bash
  jira init --installation local --server https://jira.example.com --login user@example.com \
    --auth-type bearer --project PROJ --board "Board Name"
  ```

  `--installation cloud` with `--auth-type basic` for Atlassian Cloud. Add `--force` to
  overwrite an existing config.

## My issues (default answer for "my issues" / "what's on my plate")

Whenever the user asks for their issues, tickets, plate, or backlog without a narrower filter,
run the bundled script and paste its output **verbatim** as the answer (it is already a Markdown
table with linked keys, epic, sprint name, sprint state, and a one-line count summary). Do not
re-query with ad-hoc `jira issue list` calls and hand-build a table.

**Default scope is the active sprints only.** Fetching everything assigned to the user buries
the current sprint under the backlog, so the plain invocation restricts to
`sprint in openSprints()`. Pass `--all` when the user actually asks for the backlog, for
everything, or for issues you already know are not in a sprint.

```bash
bash ~/.claude/skills/jira/scripts/my-issues.sh              # DEFAULT: mine, != Done, active sprint
bash ~/.claude/skills/jira/scripts/my-issues.sh --all        # + backlog and closed sprints
bash ~/.claude/skills/jira/scripts/my-issues.sh -pOTHER      # another project
bash ~/.claude/skills/jira/scripts/my-issues.sh --all -sDone # extra jira issue list flags pass through
```

Columns: Key, Status, Priority, Epic, Sprint, Sprint state (`active` / `future` / `closed` /
`—`), Summary. Rows are ordered active sprint first, then future, closed, and no sprint. After
the table, add at most one or two lines of observation (clusters, anything in progress,
oddities, issues with no epic); do not restate the rows.

If the default run comes back empty, say so and offer `--all` rather than silently widening.

How it resolves epic and sprint (useful if you need the same data for another query):
- `jira issue list --raw` **strips custom fields**, and both epic link and sprint are custom
  fields. `jira issue view KEY --raw` keeps them, so the script runs one view per issue,
  six at a time via `xargs -P 6`.
- Epic link field id comes from `epic.link` in `~/.config/.jira/.config.yml` (e.g.
  `customfield_10405`), falling back to `.fields.parent.key` on team-managed projects.
- Sprint is found generically: any array field whose elements are greenhopper strings (Data
  Center) or `{name, state}` objects (Cloud). When an issue is in several sprints, active wins
  over future over closed.
- `sprint is EMPTY` is the backlog; `sprint in openSprints()` is the default scope.

If the script fails with `tls: failed to verify certificate: x509`, it ran inside the Claude Code
sandbox, which cannot see the corporate trust store. Bare `jira …` commands are excluded from the
sandbox; a script that wraps them is not. Ask the user to add the script to
`sandbox.excludedCommands` in `~/.claude/settings.json`:

```json
"bash /Users/<you>/.claude/skills/jira/scripts/my-issues.sh*"
```

Fallback when the script is unavailable: run the same steps as bare `jira` commands and assemble
the seven-column table yourself.

```bash
jira issue list -a"$(jira me)" -s~Done -q"sprint in openSprints()" \
  --plain --no-headers --columns key,status,priority,summary
jira issue view PROJ-123 --raw | jq -r '.fields.customfield_10405'   # epic, per issue
```

## Read

```bash
# My open issues in the default project (prefer scripts/my-issues.sh for the full table)
jira issue list -a"$(jira me)" -s~Done --plain --columns key,status,priority,summary

# Unassigned, not closed
jira issue list -ax -s~Closed --plain

# Current sprint (uses configured board); --prev / --next also work
jira sprint list --current --plain --columns key,status,assignee,summary

# Free-text search in summary/description
jira issue list "payment timeout" --plain

# Raw JQL (project context added automatically; use -q with project clause to cross projects)
jira issue list -q'status = "In Review" AND updated >= -7d' --plain
jira issue list -q'project IS NOT EMPTY AND assignee = currentUser()' --plain --paginate 0:50

# Filters compose: type, status (repeatable), priority, label, component, parent, dates
jira issue list -tBug -yHigh -s"In Progress" -lbackend --created -14d --plain

# One issue, with description and last N comments
jira issue view PROJ-123 --plain --comments 5

# Everything as JSON (jq-friendly)
jira issue view PROJ-123 --raw | jq '.fields.status.name'
jira issue list -a"$(jira me)" --raw | jq -r '.issues[] | "\(.key)\t\(.fields.summary)"'

# Epics and their children
jira epic list --table --plain --columns key,status,summary
jira epic list PROJ-100 --plain

# Sprints as a table
jira sprint list --table --plain --columns id,name,state,start,end
```

Status filter syntax: `-sDone` match, `-s~Done` negate, repeat `-s` for several. Assignee `x`
means unassigned. `--columns` accepts: type, key, summary, status, assignee, reporter,
priority, resolution, created, updated, labels.

## Write

### Creating an issue

Two things are **always** true of an issue created through this skill, whether or not the user
mentions them:

1. **Assignee is the user.** Pass `-a"$(jira me)"` on every `jira issue create`. Only use a
   different assignee if the user names one.
2. **It belongs to an epic.** `jira issue create` has no epic flag, so this is a second command:
   `jira epic add EPIC-KEY NEW-KEY`. Pick the epic like this:
   - The user named one: use it.
   - The summary obviously matches an existing epic, e.g. a new `MyApp - Onboard <GROUP>` story
     when a MyApp epic already holds a dozen `MyApp - Onboard ...` siblings: use it and say
     which epic you chose in your reply.
   - Otherwise **ask** before creating, and list the candidates:
     `jira epic list --table --plain --columns key,status,summary`.
     Do not create an epic-less issue and fix it later unless explicitly instructed by the user.

To find the obvious epic, look at what sibling issues already use:

```bash
# Epics in the project
jira epic list --table --plain --columns key,status,summary

# The epic of a similar existing issue (epic link is a custom field: view, not list)
ef="$(awk '/^epic:/{e=1;next} e&&/^[^ ]/{e=0} e&&$1=="link:"{print $2;exit}' ~/.config/.jira/.config.yml)"
jira issue view PROJ-123 --raw | jq -r --arg ef "$ef" '.fields[$ef] // .fields.parent.key // "none"'
```

Full create-then-place sequence:

```bash
# 1. Create, always self-assigned; --raw returns JSON with the new key
key="$(jira issue create -tStory -s"Short summary" -b"Description" -a"$(jira me)" \
       --no-input --raw | jq -r .key)"
# 2. Always attach to an epic
jira epic add PROJ-100 "$key"
# 3. Sprint, if the user asked for one (jira issue create has no sprint flag either)
jira sprint add "$(jira sprint list --state active --table --plain --no-headers --columns id \
  | head -1)" "$key"
# 4. Story points, if the user gave them. NOT `jira issue edit --custom` — that silently
#    no-ops on Data Center (see Gotchas). Use the REST wrapper, which verifies after writing.
bash ~/.claude/skills/jira/scripts/set-story-points.sh "$key" 3
```

### Story points (and other numeric custom fields)

`jira issue edit --custom "Story Points=N"` does not work on Jira Data Center — it exits 0 and
prints the issue URL while the field stays unchanged. Always go through the script:

```bash
bash ~/.claude/skills/jira/scripts/set-story-points.sh PROJ-123 3      # set, then verify
bash ~/.claude/skills/jira/scripts/set-story-points.sh PROJ-123        # read current value
```

Default field name is `Story Points`. Override with `JIRA_STORY_POINTS_FIELD` (Claude Code
`env` in `~/.claude/settings.json`) or `--field NAME` for a one-off. The field id is resolved
from `issue.fields.custom` in the jira-cli config (the id varies per server — do not hardcode
one). The script does the REST `PUT`, then re-reads the field and exits non-zero if the
value did not land. Output is one line, e.g.
`PROJ-123 Story Points (customfield_<id>) = 3.0 — verified`.
If the field is missing from the config, the script prints how to declare it and lists the
custom fields already present — do not invent an id.

**Do not build the curl call yourself.** The script reads `JIRA_API_TOKEN` from the environment
and writes it to a mode-600 curl config file; the token never appears in a command line, in
output, or in this conversation. Never ask the user for the token and never put it in a command.

Same sandbox caveat as `my-issues.sh`: a `tls: failed to verify certificate: x509` or a
connection error means the wrapper is not in `sandbox.excludedCommands` in
`~/.claude/settings.json`. Ask the user to add:

```json
"bash /Users/<you>/.claude/skills/jira/scripts/set-story-points.sh*"
```

### Other writes

```bash
# Other create shapes (still add -a"$(jira me)" and an epic)
jira issue create -tBug -yHigh -s"Summary" -b$'Line one\n\nLine two' -a"$(jira me)" --no-input --raw
jira issue create -tSub-task -PPROJ-123 -s"Subtask summary" -a"$(jira me)" --no-input  # subtask needs parent
cat body.md | jira issue create -tStory -s"Summary" -a"$(jira me)" --template - --no-input

# Edit fields (labels/components/fix-versions: prefix with - to remove)
jira issue edit PROJ-123 -s"New summary" -yMedium -lneeds-review --no-input
jira issue edit PROJ-123 --label -stale --component -Backend --no-input
echo "New description" | jira issue edit PROJ-123 --no-input

# Transition (state name must match the workflow exactly; check with issue view)
jira issue move PROJ-123 "In Progress"
jira issue move PROJ-123 Done --resolution Done --comment "Shipped in v1.4"
jira issue move PROJ-123 "In Review" -a"$(jira me)"

# Assign / unassign / default
jira issue assign PROJ-123 "$(jira me)"
jira issue assign PROJ-123 x
jira issue assign PROJ-123 default

# Comment (positional body or stdin; --internal for service-desk internal notes)
jira issue comment add PROJ-123 "Root cause: missing null check in parser." --no-input
printf 'Line one\n\nLine two\n' | jira issue comment add PROJ-123 --template - --no-input

# Link / unlink (link type must exist: Blocks, Duplicate, Relates, Cloners ...)
jira issue link PROJ-123 PROJ-456 Blocks
jira issue unlink PROJ-123 PROJ-456

# Epic membership (required on every issue you create; also moves existing issues)
jira epic add PROJ-100 PROJ-123 PROJ-124

# Sprint membership (jira issue create has no sprint flag)
jira sprint list --state active --table --plain --columns id,name,state
jira sprint add 198644 PROJ-123

# Log time
jira issue worklog add PROJ-123 "1h 30m" --comment "Debugging flaky test" --no-input

# Watch
jira issue watch PROJ-123 "$(jira me)"
```

## Gotchas

- Non-interactive means **no TUI**. If output looks like a screen redraw, a flag is missing.
- `--no-input` skips prompts for optional fields only. Required fields (type, summary, parent
  for subtasks) must be passed or the command exits with an error.
- Status, type, priority, and user names must match Jira exactly, including case and spaces.
  Quote them. On a miss, run `jira issue view KEY --plain` to read the real values.
- Assignee by display name must be an exact match; email is safer.
- `--project` on `jira init` is the default project key. `-p` on other commands overrides it.
- Custom fields go through `--custom name=value`; the field must be declared in the config
  under `issue.fields.custom`. Check the config before using one.
- **`jira issue edit --custom "Story Points=N"` silently no-ops on Jira Data Center.** It exits
  0 and prints the issue URL, but the field is unchanged. Variants like `"story points"` and
  `"storypoints"` are accepted and ignored the same way; only `"story-points"` errors out, so
  a clean exit proves nothing. Use `scripts/set-story-points.sh` (see Write → Story points):
  it resolves the field id from `issue.fields.custom` in `~/.config/.jira/.config.yml`, does
  a REST `PUT`, and verifies by re-reading. Do not hardcode a `customfield_*` id. **Always
  verify after setting** — for any numeric custom field, assume `--custom` may be a no-op
  until a re-read says otherwise.
- **`jira issue list --raw` drops every `customfield_*`.** Epic link and sprint are custom
  fields, so anything needing them must go through `jira issue view KEY --raw` per issue.
- `jira issue create` has no epic flag and no sprint flag. Both are follow-up commands
  (`jira epic add`, `jira sprint add`), and both take the epic/sprint first, issue keys second.
- `jira issue view` does not accept `--columns`; that flag is `issue list` only.
- Output tables are tab-separated by default. `--delimiter "|"` changes it. `--csv` for CSV.
- `jira issue list` returns at most 100 per call. Page with `--paginate 100:100` for the next
  set.
- Cloud versus Data Center differences (auth type, some field IDs) live in the config, not
  the commands. The commands above work on both.
