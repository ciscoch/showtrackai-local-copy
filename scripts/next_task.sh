#!/usr/bin/env bash
set -euo pipefail

# Grep the first unchecked item from BACKLOG.md
TASK=$(grep "^- \[ \]" BACKLOG.md | head -n1 | sed -E 's/^- \[ \] //')

if [ -z "$TASK" ]; then
  echo ""
  exit 1
else
  echo "$TASK"
  exit 0
fi

