#!/usr/bin/env bash
# Set (or read) a numeric custom field such as Story Points via the Jira REST API.
#
# `jira issue edit --custom "Story Points=N"` silently no-ops on Jira Data Center: it exits 0
# and prints the issue URL, but the field is unchanged. This script does the direct REST PUT
# that actually works, then re-reads the field to prove it landed.
#
# Usage:
#   set-story-points.sh KEY POINTS            # set, then verify
#   set-story-points.sh KEY                   # read current value only
#   set-story-points.sh --field "Other Field" KEY 3
#
# Default field name is "Story Points". Override with $JIRA_STORY_POINTS_FIELD or --field.
# The field id is resolved by that name from `issue.fields.custom` in the jira-cli config
# (~/.config/.jira/.config.yml) — it differs per server, so nothing is hardcoded.
#
# The API token is read from the environment ($JIRA_API_TOKEN) by this script only. It is
# never passed on a command line or printed; it goes into a mode-600 curl config file that is
# deleted on exit.
#
# Requires: jq, curl. Portable to bash 3.2 (macOS).

set -euo pipefail

field_name="${JIRA_STORY_POINTS_FIELD:-Story Points}"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --field|--field-name) field_name="${2:?--field needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) args+=("$1"); shift ;;
  esac
done

key="${args[0]:-}"
points="${args[1]:-}"

if [ -z "$key" ]; then
  echo "Usage: $(basename "$0") [--field NAME] KEY [POINTS]" >&2
  exit 2
fi

cfg="${JIRA_CONFIG_FILE:-$HOME/.config/.jira/.config.yml}"
[ -r "$cfg" ] || { echo "Error: jira-cli config not readable: $cfg" >&2; exit 1; }

if [ -z "${JIRA_API_TOKEN:-}" ]; then
  cat >&2 <<'EOF'
Error: JIRA_API_TOKEN is not set in this environment.
Claude Code does not load shell rc files. Add it to ~/.claude/settings.json under "env"
(with JIRA_AUTH_TYPE=bearer for a Personal Access Token) and start a new session.
EOF
  exit 1
fi

# --- config values -------------------------------------------------------------------------
server="$(awk '$1 == "server:" { print $2; exit }' "$cfg")"
login="$(awk '$1 == "login:" { print $2; exit }' "$cfg")"
auth_type="$(awk '$1 == "auth_type:" { print tolower($2); exit }' "$cfg")"
auth_type="${JIRA_AUTH_TYPE:-$auth_type}"
auth_type="$(printf '%s' "$auth_type" | tr '[:upper:]' '[:lower:]')"
[ -n "$server" ] || { echo "Error: no 'server:' in $cfg" >&2; exit 1; }
server="${server%/}"

# --- resolve field id by exact name under issue.fields.custom ------------------------------
# Entries look like:  - name: Story Points   /   key: customfield_<id>
field_id="$(awk -v want="$field_name" '
  function unquote(s) {
    sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s)
    if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) s = substr(s, 2, length(s) - 2)
    return s
  }
  /^[ \t]*- name:[ \t]*/ {
    line = $0; sub(/^[ \t]*- name:[ \t]*/, "", line)
    cur = unquote(line); next
  }
  /^[ \t]*key:[ \t]*/ {
    if (cur == want) { line = $0; sub(/^[ \t]*key:[ \t]*/, "", line); print unquote(line); exit }
  }
' "$cfg")"

if [ -z "$field_id" ]; then
  cat >&2 <<EOF
Error: custom field '$field_name' is not declared in $cfg under issue.fields.custom.

jira init should add Story Points. If this site uses a different name, set
JIRA_STORY_POINTS_FIELD to that name (and declare the field in the same config).

  issue:
    fields:
      custom:
        - name: $field_name
          key: customfield_<id>    # from your Jira; do not guess
EOF
  names="$(grep -E '^[[:space:]]*- name:' "$cfg" 2>/dev/null | sed 's/^[[:space:]]*- name:[[:space:]]*//' || true)"
  if [ -n "$names" ]; then
    echo "Custom fields currently in that config:" >&2
    printf '%s\n' "$names" | sed 's/^/  /' >&2
  fi
  exit 1
fi

# --- auth, kept out of argv and out of stdout ----------------------------------------------
umask 077
tmp="$(mktemp -d "${TMPDIR:-/tmp}/jira-sp.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

if [ "$auth_type" = "basic" ]; then
  [ -n "$login" ] || { echo "Error: basic auth needs 'login:' in $cfg" >&2; exit 1; }
  printf 'user = "%s:%s"\n' "$login" "$JIRA_API_TOKEN" >"$tmp/curlrc"
else
  printf 'header = "Authorization: Bearer %s"\n' "$JIRA_API_TOKEN" >"$tmp/curlrc"
fi
printf 'silent\nshow-error\n' >>"$tmp/curlrc"

api="$server/rest/api/2/issue/$key"

read_field() {
  local code
  code="$(curl --config "$tmp/curlrc" -o "$tmp/get.json" -w '%{http_code}' \
    -H 'Accept: application/json' "$api?fields=$field_id")"
  if [ "$code" != "200" ]; then
    echo "Error: GET $key returned HTTP $code" >&2
    head -c 500 "$tmp/get.json" >&2; echo >&2
    return 1
  fi
  jq -r --arg f "$field_id" '.fields[$f] // "null"' "$tmp/get.json"
}

# --- read-only mode ------------------------------------------------------------------------
if [ -z "$points" ]; then
  printf '%s %s (%s): %s\n' "$key" "$field_name" "$field_id" "$(read_field)"
  exit 0
fi

case "$points" in
  ''|*[!0-9.]*) echo "Error: POINTS must be a number, got '$points'" >&2; exit 2 ;;
esac

# --- set -----------------------------------------------------------------------------------
body="$(jq -nc --arg f "$field_id" --argjson v "$points" '{fields: {($f): $v}}')"
code="$(curl --config "$tmp/curlrc" -X PUT -o "$tmp/put.out" -w '%{http_code}' \
  -H 'Content-Type: application/json' --data "$body" "$api")"

case "$code" in
  200|204) ;;
  *)
    echo "Error: PUT $key returned HTTP $code" >&2
    head -c 500 "$tmp/put.out" >&2; echo >&2
    exit 1
    ;;
esac

# --- verify --------------------------------------------------------------------------------
actual="$(read_field)"
if [ "$actual" = "$points" ] || [ "$actual" = "${points%.0}" ] \
   || awk -v a="$actual" -v b="$points" 'BEGIN { exit !(a + 0 == b + 0) }' 2>/dev/null; then
  printf '%s %s (%s) = %s — verified\n' "$key" "$field_name" "$field_id" "$actual"
else
  printf 'Error: %s %s is %s after PUT, expected %s — not applied\n' \
    "$key" "$field_name" "$actual" "$points" >&2
  exit 1
fi
