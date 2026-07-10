#!/usr/bin/env bash
# Install the tracked rules files into ~/.claude/rules/ so every Claude Code session
# loads the same operating contract as the one shipped with this repo.
#
# Idempotent: safe to re-run after every pull. Overwrites any existing files with
# the same name — user-scope customizations should go in a separate ~/.claude/rules/local/
# subdirectory that this script does NOT touch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HOME}/.claude/rules"

mkdir -p "${DEST}"

for f in codex-routing.md workflows.md sprint-status.md hooks.md; do
    src="${REPO_ROOT}/rules/${f}"
    dst="${DEST}/${f}"
    if [[ ! -f "${src}" ]]; then
        echo "WARN: missing source ${src}" >&2
        continue
    fi
    cp "${src}" "${dst}"
    echo "installed ${dst}"
done

echo "done."
