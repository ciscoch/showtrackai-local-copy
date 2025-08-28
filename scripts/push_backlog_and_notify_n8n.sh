#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# n8n prod webhook URL
N8N_WEBHOOK_URL="${N8N_WEBHOOK_URL:-https://showtrackai.app.n8n.cloud/webhook/backlog-to-linear}"

# Repo coordinates
GIT_OWNER="${GIT_OWNER:-showtrackai}"
GIT_REPO="${GIT_REPO:-showtrackai-local-copy}"
BACKLOG_FILE="${BACKLOG_FILE:-BACKLOG.md}"   # adjust if file lives elsewhere, e.g. docs/BACKLOG.md

# Behavior
COMMIT_AND_PUSH="${COMMIT_AND_PUSH:-1}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing tool: $1" >&2; exit 1; }; }
need git
need curl
need jq

branch() { git rev-parse --abbrev-ref HEAD; }

# 1) Optionally commit & push changes to BACKLOG.md
if [ "$COMMIT_AND_PUSH" = "1" ]; then
  if ! git diff --quiet -- "$BACKLOG_FILE" || ! git diff --cached --quiet -- "$BACKLOG_FILE"; then
    git add "$BACKLOG_FILE"
    git commit -m "chore(backlog): update ${BACKLOG_FILE}"
  fi
  CUR_BRANCH="$(branch)"
  git push -u origin "$CUR_BRANCH"
fi

# 2) Find before/after SHAs (prefer last two commits touching BACKLOG.md)
AFTER_SHA="$(git log -n 1 --format=%H -- "$BACKLOG_FILE" || true)"
BEFORE_SHA="$(git log -n 1 --format=%H --skip=1 -- "$BACKLOG_FILE" || true)"
if [ -z "$AFTER_SHA" ] || [ -z "$BEFORE_SHA" ]; then
  AFTER_SHA="$(git rev-parse HEAD)"
  BEFORE_SHA="$(git rev-parse HEAD~1 2>/dev/null || echo "$AFTER_SHA")"
fi

# 3) Get the file bodies at those SHAs (robust fallback)
get_blob() {
  local sha="$1" path="$2"
  git show "${sha}:${path}" 2>/dev/null || echo ""
}

BEFORE_BODY="$(get_blob "$BEFORE_SHA" "$BACKLOG_FILE")"
AFTER_BODY="$(get_blob  "$AFTER_SHA"  "$BACKLOG_FILE")"

# If AFTER_BODY is empty, fall back to working tree (uncommitted/new file)
if [ -z "$AFTER_BODY" ] && [ -f "$BACKLOG_FILE" ]; then
  AFTER_BODY="$(cat "$BACKLOG_FILE")"
fi

# If BEFORE_BODY is empty, try parent commit of AFTER
if [ -z "$BEFORE_BODY" ]; then
  PARENT="$(git rev-parse "${AFTER_SHA}^" 2>/dev/null || echo "")"
  if [ -n "$PARENT" ]; then
    BEFORE_BODY="$(get_blob "$PARENT" "$BACKLOG_FILE")"
  fi
fi

echo "📦 Repo: ${GIT_OWNER}/${GIT_REPO}"
echo "🌿 Branch: $(branch)"
echo "📝 Backlog file: $BACKLOG_FILE"
echo "🔎 SHAs: before=$BEFORE_SHA  after=$AFTER_SHA"
echo "🧾 byte lengths — before: ${#BEFORE_BODY} | after: ${#AFTER_BODY}"
echo "🌐 Webhook: $N8N_WEBHOOK_URL"

# 4) Build payload and POST
payload="$(jq -nc \
  --arg before "$BEFORE_SHA" \
  --arg after "$AFTER_SHA" \
  --arg owner "$GIT_OWNER" \
  --arg repo "$GIT_REPO" \
  --arg path "$BACKLOG_FILE" \
  --arg beforeBody "$BEFORE_BODY" \
  --arg afterBody "$AFTER_BODY" \
  '{before:$before, after:$after, owner:$owner, repo:$repo, path:$path, beforeBody:$beforeBody, afterBody:$afterBody}')"

HTTP_STATUS=$(curl -sS -o /tmp/n8n_resp.txt -w "%{http_code}" \
  -X POST "$N8N_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data-binary "$payload")

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "✅ Notified n8n. Response:"; cat /tmp/n8n_resp.txt; echo
else
  echo "❌ n8n webhook returned HTTP $HTTP_STATUS"
  echo "Response:"; cat /tmp/n8n_resp.txt; echo
  exit 1
fi

