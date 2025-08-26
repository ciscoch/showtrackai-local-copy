#!/usr/bin/env bash
set -euo pipefail

GOAL="${1:-improve the codebase}"
BRANCH="cc-cycle-$(date +%Y%m%d-%H%M%S)"

# Start a working branch (safe if not a git repo)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git checkout -b "$BRANCH"
fi

echo "▶️  Starting perpetual cycle for: $GOAL"
echo "    Branch: ${BRANCH}"

while true; do
  echo ""
  echo "— Cycle begin — $(date)"
  claude "/generate $GOAL"
  claude "/review"
  claude "/refactor"
  claude "/optimize"

  # If checks fail, give Claude a chance to self-heal
  if ! scripts/healthcheck.sh; then
    echo "❌ Healthcheck failed — invoking /fix-tests"
    claude "/fix-tests"
  else
    echo "✅ Healthcheck OK"
  fi

  # Optional: push progress every loop (best for CI)
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git push -u origin "$BRANCH" || true
  fi

  # Backoff to avoid hammering tools/CI
  sleep 10
done

