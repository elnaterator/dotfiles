#!/usr/bin/env bash
# append-note.sh — append a scratch note entry to the centralized notes file.
#
# Target file: $SCRATCH_NOTES_FILE (default: ~/notes.md)
# Each entry is separated from the previous content by a `---` line.
#
# Usage:
#   append-note.sh "line one" "line two" ...   # each arg becomes its own line
#   echo "note text" | append-note.sh          # or read entry from stdin
#   append-note.sh --file /path/to/notes.md "line"   # override target file

set -euo pipefail

FILE="${SCRATCH_NOTES_FILE:-$HOME/notes.md}"

if [ "${1:-}" = "--file" ]; then
    if [ -z "${2:-}" ]; then
        echo "Error: --file requires a path argument" >&2
        exit 1
    fi
    FILE="$2"
    shift 2
fi

# Expand a leading ~ that survived shell quoting (e.g. SCRATCH_NOTES_FILE='~/notes.md')
FILE="${FILE/#\~/$HOME}"

if [ $# -gt 0 ]; then
    CONTENT="$(printf '%s\n' "$@")"
else
    CONTENT="$(cat)"
fi

if [ -z "${CONTENT//[[:space:]]/}" ]; then
    echo "Error: no note content provided (pass args or pipe via stdin)" >&2
    exit 1
fi

mkdir -p "$(dirname "$FILE")"

# Separator before every entry except the very first in the file
if [ -s "$FILE" ]; then
    printf '\n---\n\n' >> "$FILE"
fi

printf '%s\n' "$CONTENT" >> "$FILE"

echo "Note appended to $FILE"
