#!/usr/bin/env bash
# PostToolUse hook — track lines added/deleted per session
# Fires on: Edit | Write | MultiEdit
# Writes:   /tmp/claude-code-stats-{session_id}  (JSON counters)
# Read by:  ~/.claude/statusline-command.sh (CÓDIGO line)

export PATH="$PATH:/c/Users/lanitaEmperadora/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe"

input=$(cat)
tool_name=$(echo "$input"  | jq -r '.tool_name  // ""')
session_id=$(echo "$input" | jq -r '.session_id // "default"')
STATS_FILE="/tmp/claude-code-stats-${session_id}"

[ ! -f "$STATS_FILE" ] && \
    printf '{"lines_added":0,"lines_deleted":0,"files_edited":0,"edit_count":0}' \
    > "$STATS_FILE"

lines_added=0; lines_deleted=0; files_delta=0; edits_delta=0

case "$tool_name" in
    Edit)
        old=$(echo "$input" | jq -r '.tool_input.old_string // ""')
        new=$(echo "$input" | jq -r '.tool_input.new_string // ""')
        lines_deleted=$(printf '%s' "$old" | wc -l)
        lines_added=$(printf '%s'  "$new" | wc -l)
        files_delta=1; edits_delta=1
        ;;
    Write)
        content=$(echo "$input" | jq -r '.tool_input.content // ""')
        lines_added=$(printf '%s' "$content" | wc -l)
        files_delta=1; edits_delta=1
        ;;
    MultiEdit)
        while IFS= read -r edit; do
            [ -z "$edit" ] && continue
            old=$(echo "$edit" | jq -r '.old_string // ""')
            new=$(echo "$edit" | jq -r '.new_string // ""')
            lines_deleted=$(( lines_deleted + $(printf '%s' "$old" | wc -l) ))
            lines_added=$(( lines_added + $(printf '%s' "$new" | wc -l) ))
            edits_delta=$(( edits_delta + 1 ))
        done < <(echo "$input" | jq -c '.tool_input.edits[]?' 2>/dev/null)
        [ "$edits_delta" -gt 0 ] && files_delta=1
        ;;
    *)
        exit 0
        ;;
esac

updated=$(jq \
    --argjson la "$lines_added"  \
    --argjson ld "$lines_deleted" \
    --argjson fd "$files_delta"  \
    --argjson ed "$edits_delta"  \
    '{
        lines_added:   (.lines_added   + $la),
        lines_deleted: (.lines_deleted + $ld),
        files_edited:  (.files_edited  + $fd),
        edit_count:    (.edit_count    + $ed)
    }' "$STATS_FILE")

printf '%s' "$updated" > "$STATS_FILE"
exit 0
