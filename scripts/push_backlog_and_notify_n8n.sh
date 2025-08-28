#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Hard-wire your n8n webhook (can be overridden by env)
N8N_WEBHOOK_URL="${N8N_WEBHOOK_URL:-https://showtrackai.app.n8n.cloud/webhook-test/backlog-to-linear}"
BACKLOG_FILE="${BACKLOG_FILE:-BACKLOG.md}"
COMMIT_AND_PUSH="${COMMIT_AND_PUSH:-1}"    # set to 0 to skip auto-commit/push

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing tool: $1" >&2; exit 1; }; }
need git
need curl
need jq

branch() { git rev-parse --abbrev-ref HEAD; }

# 1) Commit & push BACKLOG.md (optional)
if [ "$COMMIT_AND_PUSH" = "1" ]; then
  if ! git diff --quiet -- "$BACKLOG_FILE" || ! git diff --cached --quiet -- "$BACKLOG_FILE"; then
    git add "$BACKLOG_FILE"
    git commit -m "chore(backlog): update BACKLOG.md"
  fi
  CUR_BRANCH="$(branch)"
  git push -u origin "$CUR_BRANCH"
fi

# 2) Determine before/after SHAs (prefer last two commits touching BACKLOG.md)
AFTER_SHA="$(git log -n 1 --format=%H -- "$BACKLOG_FILE" || true)"
BEFORE_SHA="$(git log -n 1 --format=%H --skip=1 -- "$BACKLOG_FILE" || true)"
if [ -z "$AFTER_SHA" ] || [ -z "$BEFORE_SHA" ]; then
  AFTER_SHA="$(git rev-parse HEAD)"
  BEFORE_SHA="$(git rev-parse HEAD~1 2>/dev/null || echo "$AFTER_SHA")"
fi

echo "📦 Repo: $(basename "$ROOT_DIR")"
echo "🌿 Branch: $(branch)"
echo "📝 Backlog file: $BACKLOG_FILE"
echo "🔎 SHAs: before=$BEFORE_SHA  after=$AFTER_SHA"
echo "🌐 Webhook: $N8N_WEBHOOK_URL"

# 3) Notify n8n (GitHub-style minimal push payload)
payload="$(jq -nc --arg before "$BEFORE_SHA" --arg after "$AFTER_SHA" '{before:$before, after:$after}')"

HTTP_STATUS=$(curl -sS -o /tmp/n8n_resp.txt -w "%{http_code}" \
  -X POST "$N8N_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data-binary "$payload")

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "✅ Notified n8n. Response:"
  cat /tmp/n8n_resp.txt; echo
else
  echo "❌ n8n webhook returned HTTP $HTTP_STATUS"
  echo "Response:"
  cat /tmp/n8n_resp.txt; echo
  exit 1
fi

