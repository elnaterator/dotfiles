#!/usr/bin/env bash
# Print the caller's open Jira issues as a Markdown table, with epic, sprint name and sprint state.
#
# Usage: my-issues.sh [--all] [extra `jira issue list` flags]
#   my-issues.sh                 # DEFAULT: mine, status != Done, in an ACTIVE sprint
#   my-issues.sh --all           # drop the active-sprint restriction (backlog + closed sprints too)
#   my-issues.sh -pOTHER         # another project
#   my-issues.sh -s"In Progress" # narrow further (ANDed with the default -s~Done; -s~X negates)
#   my-issues.sh -tBug -yHigh    # any other `jira issue list` filter
#
# Epic and sprint both come from `jira issue view KEY --raw`: `jira issue list --raw` strips
# custom fields, and epic link / sprint are custom fields. Views run in parallel.
# The epic-link field id is read from `epic.link` in the jira-cli config, falling back to
# `.fields.parent.key` for team-managed projects.
# Portable to bash 3.2 (macOS). Requires: jira (ankitpokhrel/jira-cli), jq.

set -euo pipefail

me="$(jira me)"
cfg="${JIRA_CONFIG_FILE:-$HOME/.config/.jira/.config.yml}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/jira-my-issues.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# --- args ---------------------------------------------------------------------------------
active_only=1
pass=()
for a in "$@"; do
  case "$a" in
    --all) active_only=0 ;;
    *) pass+=("$a") ;;
  esac
done

scope=()
if [ "$active_only" -eq 1 ]; then
  scope=(-q"sprint in openSprints()")
fi

# Note: `${arr[@]}` on an empty array is an unbound-variable error under bash 3.2 + set -u,
# hence the `${arr[@]+"${arr[@]}"}` expansions below.

# --- issues -------------------------------------------------------------------------------
# shellcheck disable=SC2046
jira issue list -a"$me" -s~Done ${scope[@]+"${scope[@]}"} ${pass[@]+"${pass[@]}"} \
  --raw --paginate 0:100 >"$tmp/raw.json" 2>"$tmp/raw.err" || true

if ! jq -e 'type == "array" and length > 0' "$tmp/raw.json" >/dev/null 2>&1; then
  if grep -qi 'error' "$tmp/raw.err" "$tmp/raw.json" 2>/dev/null; then
    echo "jira issue list failed:" >&2
    cat "$tmp/raw.err" "$tmp/raw.json" >&2
    echo "(TLS x509 errors from a corporate proxy are usually transient; re-run.)" >&2
    exit 1
  fi
  if [ "$active_only" -eq 1 ]; then
    echo "No issues assigned to you in an active sprint. Re-run with --all to include the backlog."
  else
    echo "No issues found."
  fi
  exit 0
fi

# key<TAB>status<TAB>priority<TAB>summary
jq -r '
  .[] | [
    .key,
    (.fields.status.name // ""),
    (.fields.priority.name // ""),
    ((.fields.summary // "") | gsub("[\r\n\t]+"; " "))
  ] | @tsv' "$tmp/raw.json" >"$tmp/issues.tsv"

first_key="$(head -1 "$tmp/issues.tsv" | cut -f1)"
base_url="$(jira open "$first_key" --no-browser 2>/dev/null | sed 's#/browse/.*##' || true)"

# --- epic-link field id from the jira-cli config ------------------------------------------
epic_field="$(awk '
  /^epic:/ { in_epic = 1; next }
  in_epic && /^[^[:space:]]/ { in_epic = 0 }
  in_epic && $1 == "link:" { print $2; exit }
' "$cfg" 2>/dev/null || true)"
[ -z "$epic_field" ] && epic_field="__none__"

# --- per-issue detail: key<TAB>epic<TAB>sprint name<TAB>sprint state ----------------------
# Sprint is found generically (any array field holding greenhopper strings or {name,state}
# objects) so this works on Data Center and Cloud without naming the field.
cat >"$tmp/detail.sh" <<'DETAIL'
#!/usr/bin/env bash
k="$1"; epic_field="$2"
jira issue view "$k" --raw 2>/dev/null | jq -r --arg k "$k" --arg ef "$epic_field" '
  .fields as $f
  | (($f[$ef] // $f.parent.key // "") | if type == "object" then (.key // "") else tostring end) as $epic
  | ([ $f | to_entries[] | .value
       | select(type == "array")
       | .[]
       | if type == "string" and test("rapidViewId|greenhopper") then
           { name: (capture("name=(?<n>[^,\\]]*)").n),
             state: (capture("state=(?<s>[^,\\]]*)").s | ascii_downcase) }
         elif type == "object" and has("name") and has("state") then
           { name: (.name | tostring), state: (.state | tostring | ascii_downcase) }
         else empty end ]) as $sp
  | ( ($sp | map(select(.state == "active")))
      + ($sp | map(select(.state == "future")))
      + ($sp | map(select(.state == "closed")))
      + $sp | first ) as $best
  | [ $k, $epic, ($best.name // "—"), ($best.state // "—") ] | @tsv
' || printf '%s\t\t—\t—\n' "$k"
DETAIL
chmod +x "$tmp/detail.sh" 2>/dev/null || true

cut -f1 "$tmp/issues.tsv" \
  | xargs -P 6 -I{} bash "$tmp/detail.sh" {} "$epic_field" >"$tmp/detail.tsv" 2>/dev/null || true

# --- render -------------------------------------------------------------------------------
awk -F'\t' -v base="$base_url" -v scope="$active_only" '
  function rank(s) { return s == "active" ? 0 : s == "future" ? 1 : s == "closed" ? 2 : 3 }
  function link(k) { return (base != "" && k != "" && k != "—") \
                            ? "[" k "](" base "/browse/" k ")" : (k == "" ? "—" : k) }
  BEGIN {
    print "| Key | Status | Priority | Epic | Sprint | Sprint state | Summary |"
    print "|---|---|---|---|---|---|---|"
    sortcmd = "sort -t\"\t\" -k1,1n -k2,2n | cut -f3-"
  }
  FNR == NR && FILENAME == ARGV[1] { epic[$1] = $2; name[$1] = $3; state[$1] = $4; next }
  {
    key = $1
    ep = (key in epic) ? epic[key] : ""
    sn = (key in name && name[key] != "") ? name[key] : "—"
    st = (key in state && state[key] != "") ? state[key] : "—"
    gsub(/\\\\/, "\\", $4); gsub(/\|/, "\\|", $4)
    n[st == "active" ? "a" : st == "future" ? "f" : st == "closed" ? "c" : "x"]++
    if (ep == "" || ep == "—") noepic++
    total++
    printf "%d\t%d\t| %s | %s | %s | %s | %s | %s | %s |\n", \
      rank(st), FNR, link(key), $2, $3, link(ep), sn, st, $4 | sortcmd
  }
  END {
    close(sortcmd)
    if (scope == 1)
      printf "\n%d issues in active sprints — %d without an epic. (Add --all for backlog and closed sprints.)\n", \
        total, noepic + 0
    else
      printf "\n%d issues — active sprint: %d, future sprint: %d, closed sprint only: %d, no sprint: %d; %d without an epic.\n", \
        total, n["a"] + 0, n["f"] + 0, n["c"] + 0, n["x"] + 0, noepic + 0
  }
' "$tmp/detail.tsv" "$tmp/issues.tsv"
