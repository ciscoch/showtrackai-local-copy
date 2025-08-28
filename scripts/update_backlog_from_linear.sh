#!/usr/bin/env bash
set -euo pipefail

# ── Resolve repo root & cd there ───────────────────────────────────────────────
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ── Load .env (from repo root) ─────────────────────────────────────────────────
if [ -f ".env" ]; then
  set -o allexport
  # shellcheck disable=SC1091
  source ".env"
  set +o allexport
fi

# ── CONFIG ─────────────────────────────────────────────────────────────────────
: "${LINEAR_API_KEY:?Set LINEAR_API_KEY in .env or environment (e.g. lin_api_...)}"
LINEAR_TEAM_ID="${LINEAR_TEAM_ID:-}"   # optional team UUID filter
LINEAR_API_URL="${LINEAR_API_URL:-https://api.linear.app/graphql}"
BACKLOG_FILE="${BACKLOG_FILE:-$ROOT_DIR/BACKLOG.md}"
SECTION_BEGIN="<!-- BEGIN LINEAR ASSIGNED -->"
SECTION_END="<!-- END LINEAR ASSIGNED -->"
MAX_ITEMS="${MAX_ITEMS:-50}"
VERBOSE="${VERBOSE:-1}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing required tool: $1" >&2; exit 1; }; }
need curl
need jq

log() { [ "$VERBOSE" = "1" ] && echo "🔎 $*"; }
ts() { date -u +"%Y-%m-%d %H:%M:%S UTC"; }

# ── GraphQL helper ────────────────────────────────────────────────────────────
gq() {
  local QUERY="$1"
  local VARS_JSON="${2:-}"

  local BODY
  if [ -z "$VARS_JSON" ]; then
    BODY=$(jq -cn --arg q "$QUERY" '{query:$q, variables:{}}')
  else
    if ! printf '%s' "$VARS_JSON" | jq -e . >/dev/null 2>&1; then
      echo "❌ VARS_JSON is not valid JSON:"; printf '%s\n' "$VARS_JSON"; exit 1
    fi
    BODY=$(jq -cn --arg q "$QUERY" --slurpfile v <(printf '%s' "$VARS_JSON") \
           '{query:$q, variables: ($v[0] // {}) }')
  fi

  local RESP
  RESP=$(curl -sS "$LINEAR_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: ${LINEAR_API_KEY}" \
    --data-binary "$BODY")

  echo "$RESP" | jq -e '.data' >/dev/null 2>&1 || {
    echo "❌ Linear API error:"; echo "$RESP" | sed 's/\\n/\n/g'
    echo "–– Request body ––"; echo "$BODY"; exit 1
  }
  echo "$RESP"
}

viewer_id() {
  local QUERY='query { viewer { id } }'
  local R; R=$(gq "$QUERY" '')
  echo "$R" | jq -r '.data.viewer.id'
}

fetch_assigned() {
  local ME="$1"
  local QUERY VARS_JSON
  if [ -n "$LINEAR_TEAM_ID" ]; then
    QUERY='query($me: ID!, $team: ID!, $n: Int!){
      issues(first:$n,
        filter:{ assignee:{ id:{ eq:$me } }, team:{ id:{ eq:$team } } }
      ){ nodes { identifier title url priority createdAt state { name type } } }
    }'
    VARS_JSON=$(jq -nc --arg me "$ME" --arg team "$LINEAR_TEAM_ID" --argjson n "$MAX_ITEMS" '{me:$me, team:$team, n:$n}')
  else
    QUERY='query($me: ID!, $n: Int!){
      issues(first:$n,
        filter:{ assignee:{ id:{ eq:$me } } }
      ){ nodes { identifier title url priority createdAt state { name type } } }
    }'
    VARS_JSON=$(jq -nc --arg me "$ME" --argjson n "$MAX_ITEMS" '{me:$me, n:$n}')
  fi
  gq "$QUERY" "$VARS_JSON"
}

render_md_list() {
  jq -r '
    def box($s): (if ($s|tostring|ascii_downcase) as $t
                    | ($t=="done" or $t=="completed" or $t=="canceled" or $t=="merged")
                  then "x" else " " end);
    .[] | "- [" + (box(.state.type // .state.name // "")) + "] [" + .identifier + ": " + (.title|gsub("\\n"; " ")) + "](" + .url + ")"
  '
}

# ── Fixed write_section for macOS awk ─────────────────────────────────────────
write_section() {
  local content="$1"
  local hdr="## Linear — My Assigned (updated $(ts))"

  # build replacement block in a temp file
  local TMP_BLOCK
  TMP_BLOCK="$(mktemp)"
  {
    echo "$SECTION_BEGIN"
    echo "$hdr"
    echo
    printf "%s\n" "$content"
    echo
    echo "$SECTION_END"
  } > "$TMP_BLOCK"

  [ -f "$BACKLOG_FILE" ] || touch "$BACKLOG_FILE"

  if grep -qF "$SECTION_BEGIN" "$BACKLOG_FILE"; then
    awk -v begin="$SECTION_BEGIN" -v end="$SECTION_END" -v blk="$TMP_BLOCK" '
      $0==begin {
        while ((getline line < blk) > 0) print line
        insec=1
        next
      }
      $0==end { insec=0; next }
      insec==0 { print }
    ' "$BACKLOG_FILE" > "${BACKLOG_FILE}.tmp" && mv "${BACKLOG_FILE}.tmp" "$BACKLOG_FILE"
  else
    { cat "$BACKLOG_FILE"; echo; cat "$TMP_BLOCK"; } > "${BACKLOG_FILE}.tmp" && mv "${BACKLOG_FILE}.tmp" "$BACKLOG_FILE"
  fi

  rm -f "$TMP_BLOCK"
}

main() {
  echo "🛠 Repo root: $ROOT_DIR"
  echo "🗂 Backlog file: $BACKLOG_FILE"
  echo "🔑 API key length: $(printf %s "$LINEAR_API_KEY" | wc -c | tr -d ' ')"

  echo "🔎 Resolving viewer id…"
  local ME; ME=$(viewer_id)
  echo "🙋 viewer.id = $ME"

  log "Fetching assigned issues (team filter: ${LINEAR_TEAM_ID:-<none>})…"
  local RESP; RESP=$(fetch_assigned "$ME")
  local NODES; NODES=$(echo "$RESP" | jq '.data.issues.nodes')
  local COUNT; COUNT=$(echo "$NODES" | jq 'length')

  echo "📥 Found $COUNT assigned issue(s)."

  if (( COUNT == 0 )); then
    write_section "_No assigned issues found in the selected scope._"
    echo "ℹ️ No issues found. Section updated in $BACKLOG_FILE."
    exit 0
  fi

  local MD; MD=$(echo "$NODES" | jq 'sort_by(.priority, .createdAt)' | render_md_list)
  write_section "$MD"
  echo "✅ Wrote $COUNT issue(s) into $BACKLOG_FILE between markers."
}

main "$@"
