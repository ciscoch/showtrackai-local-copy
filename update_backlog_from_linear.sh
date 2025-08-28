#!/usr/bin/env bash
set -euo pipefail

# ── CONFIG ─────────────────────────────────────────────────────────────────────
# Required:
: "${LINEAR_API_KEY:?Set LINEAR_API_KEY (Bearer token e.g. lin_api_...)}"
# Optional filter to a single team (UUID). If unset, pulls from all teams.
LINEAR_TEAM_ID="${LINEAR_TEAM_ID:-}"

LINEAR_API_URL="${LINEAR_API_URL:-https://api.linear.app/graphql}"
BACKLOG_FILE="${BACKLOG_FILE:-BACKLOG.md}"
SECTION_BEGIN="<!-- BEGIN LINEAR ASSIGNED -->"
SECTION_END="<!-- END LINEAR ASSIGNED -->"
MAX_ITEMS="${MAX_ITEMS:-50}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 1; }; }
need curl
need jq
ts() { date -u +"%Y-%m-%d %H:%M:%S UTC"; }

gq() { # linear graphql: $1=query, $2=variables (json)
  curl -sS "$LINEAR_API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${LINEAR_API_KEY}" \
    --data "{\"query\":$1,\"variables\":$2}"
}

viewer_id() {
  local q='"query { viewer { id } }"'
  local r; r=$(gq "$q" 'null')
  echo "$r" | jq -er '.data.viewer.id'
}

fetch_issues_all() {
  local me="$1"
  local q
  if [[ -n "${LINEAR_TEAM_ID}" ]]; then
    q='"query($me:String!, $team:String!, $n:Int!){ issues(first:$n, filter:{ assignee:{id:{eq:$me}}, team:{id:{eq:$team}} }, orderBy:[{field: priority, direction: ASC},{field: createdAt, direction: ASC}]) { nodes { identifier title url state { name type } } } }"'
    local v; v=$(jq -cn --arg me "$me" --arg team "$LINEAR_TEAM_ID" --argjson n "$MAX_ITEMS" '{me:$me, team:$team, n:$n}')
    gq "$q" "$v"
  else
    q='"query($me:String!, $n:Int!){ issues(first:$n, filter:{ assignee:{id:{eq:$me}} }, orderBy:[{field: priority, direction: ASC},{field: createdAt, direction: ASC}]) { nodes { identifier title url state { name type } } } }"'
    local v; v=$(jq -cn --arg me "$me" --argjson n "$MAX_ITEMS" '{me:$me, n:$n}')
    gq "$q" "$v"
  fi
}

render_md_list() {
  # stdin: JSON array of issues: [{identifier,title,url,state:{name,type}},...]
  jq -r '
    def box($s): (if ($s|ascii_downcase) as $t
                    | ($t=="done" or $t=="canceled" or $t=="completed" or $t=="merged")
                  then "x" else " " end);
    .[] | "- [" + (box(.state.type // .state.name // "")) + "] [" + .identifier + ": " + (.title|gsub("\\n"; " ")) + "](" + .url + ")"
  '
}

write_section() {
  local content="$1"
  local hdr="## Linear — My Assigned (updated $(ts))"
  local block="$SECTION_BEGIN
$hdr

$content

$SECTION_END"
  if [[ -f "$BACKLOG_FILE" ]] && grep -q "$SECTION_BEGIN" "$BACKLOG_FILE"; then
    # replace existing section
    awk -v begin="$SECTION_BEGIN" -v end="$SECTION_END" -v repl="$block" '
      BEGIN{printed=0}
      {
        if ($0==begin) {
          print repl
          skip=1
          next
        }
        if (skip && $0==end) { skip=0; next }
        if (!skip) print
      }
      END{ if (!printed) {} }
    ' "$BACKLOG_FILE" > "${BACKLOG_FILE}.tmp"
    mv "${BACKLOG_FILE}.tmp" "$BACKLOG_FILE"
  else
    # append new section
    {
      [[ -f "$BACKLOG_FILE" ]] && cat "$BACKLOG_FILE"
      echo
      echo "$block"
    } > "${BACKLOG_FILE}.tmp"
    mv "${BACKLOG_FILE}.tmp" "$BACKLOG_FILE"
  fi
}

main() {
  echo "🔎 Updating $BACKLOG_FILE from Linear (assigned issues)…"
  local me; me=$(viewer_id)
  local resp; resp=$(fetch_issues_all "$me")

  # basic error check
  echo "$resp" | jq -e '.data.issues.nodes' >/dev/null || { echo "Linear API error:"; echo "$resp"; exit 1; }

  local nodes; nodes=$(echo "$resp" | jq '.data.issues.nodes')
  local count; count=$(echo "$nodes" | jq 'length')
  if (( count == 0 )); then
    write_section "_No assigned issues found in the selected scope._"
    echo "ℹ️ No issues found. Section updated."
    exit 0
  fi

  local md; md=$(echo "$nodes" | render_md_list)
  write_section "$md"
  echo "✅ Wrote $count issue(s) into $BACKLOG_FILE between markers."
}

main "$@"

