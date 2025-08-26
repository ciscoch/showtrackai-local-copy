#!/#!/usr/bin/env bash
set -euo pipefail

BRANCH="cc-cycle-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH" || true

while true; do
  TASK=$(./scripts/next_task.sh || true)

  if [ -z "$TASK" ]; then
    echo "🎉 Backlog empty — idling…"
    sleep 30
    continue
  fi

  echo ""
  echo "▶️ Working on: $TASK"

  claude "/generate $TASK"
  claude "/review"
  claude "/refactor"
  claude "/optimize"

  if ! scripts/healthcheck.sh; then
    claude "/fix-tests"
  fi

  # Mark task complete in BACKLOG.md
  sed -i.bak "0,/- \[ \] $TASK/{s/- \[ \] $TASK/- [x] $TASK/}" BACKLOG.md
  git add BACKLOG.md
  git commit -m "mark '$TASK' done"

  git push -u origin "$BRANCH" || true
  sleep 10
done
