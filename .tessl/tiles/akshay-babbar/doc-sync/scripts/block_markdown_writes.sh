#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"

if command -v python3 >/dev/null 2>&1; then
    HOOK_INPUT="$INPUT" python3 - <<'PY'
import json
import os
import re
import sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT", ""))
except json.JSONDecodeError:
    raise SystemExit(0)

tool_name = data.get("tool_name")
tool_input = data.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""

if tool_name in {"Edit", "Write"} and re.search(r"\.mdx$", file_path, re.IGNORECASE):
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"MDX edits are not allowed ({file_path}).",
                }
            }
        )
    )
    raise SystemExit(0)

if tool_name in {"Edit", "Write"} and re.search(r"\.md$", file_path, re.IGNORECASE):
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": f"Markdown edits require explicit approval ({file_path}).",
                }
            }
        )
    )
    raise SystemExit(0)

raise SystemExit(0)
PY
    exit $?
fi

TOOL_NAME=$(printf '%s' "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
FILE_PATH=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

shopt -s nocasematch
if [[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]] && [[ "$FILE_PATH" =~ \.mdx$ ]]; then
    printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"MDX edits are not allowed ($FILE_PATH).\"}}"
    exit 0
fi

if [[ "$TOOL_NAME" =~ ^(Edit|Write)$ ]] && [[ "$FILE_PATH" =~ \.md$ ]]; then
    printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"Markdown edits require explicit approval ($FILE_PATH).\"}}"
    exit 0
fi
shopt -u nocasematch

exit 0
