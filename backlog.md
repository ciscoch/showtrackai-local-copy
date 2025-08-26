# Backlog (Flutter Web)


## Now
- [x] Fix authentication token handling ✅
- [x] Add COPPA compliance for minors ✅
- [x] Implement input validation ✅
- [x] Add offline storage limits ✅
- [x] Create comprehensive tests ✅
- [x] Animal create page (name, tag) ✅
- [x] Journal entry form with weather + geolocation ✅
- [x] Supabase RLS (owner only) ✅
- [x] connect journal to n8n workflow at https://showtrackai.app.n8n.cloud/workflow/IA4KVsPotkhtYfW8 ✅
- [x] Push to git code_automation branch on https://github.com/ciscoch/showtrackai-local-copy.git do not merge to main ✅
## UI/UX — Journal entry → SPAR integration

## Now
- [x] Fix supabase authentication error: main.dart.js:101168 ✅ 
 POST https://zifbuzsdhparxlhsifdi.supabase.co/auth/v1/token?grant_type=password 400 (Bad Request)

main.dart.js:32343 ⚠️ Supabase authentication failed: AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)



### Core form fields (Journal payload → journal_entries)
- [x] User selector (required) → sets `user_id` ✅
- [x] Animal selector (required) → sets `animal_id` ✅
- [x] Title text input (default: "Journal Entry") → `title` ✅
- [x] Rich text / multiline input (required) → `entry_text` ✅
- [x] Date picker (YYYY-MM-DD) → `entry_date` ✅
- [x] Category select (training, feeding, health, show, general) → `category` ✅
- [x] Duration number (minutes) with stepper → `duration_minutes` ✅
- [x] FFA standards multi-select chips (e.g., AS.06.02, AS.07.01) → `ffa_standards[]` ✅
- [x] Learning objectives tokens/chips → `learning_objectives[]` ✅

### Weight/feeding mini-panel (normalizes `feed_strategy`)
- [x] Current weight (number, lbs) → `feed_strategy.current_weight` ✅
- [x] Target weight (number, lbs) → `feed_strategy.target_weight` ✅
- [x] Target/next weigh-in date → `feed_strategy.weigh_in_date` ✅

### Location & weather (best-effort)
- [x] Location widget (city, state) + hidden lat/lon when available → `location.{city,state,lat,lon}` ✅
- [x] "Attach weather" button (fills preview chip) → store compact JSON in `weather` ✅
- [x] "Use IP-based weather if GPS not granted" toggle → sets source hint ✅

### Metadata & source
- [ ] Source select (mobile_app, web_app, import, api) → `metadata.source`
- [ ] Optional notes textarea → `metadata.notes`

### Retrieval query (for vector + planner)
- [ ] Hidden field auto-composed: `${entry_text}\nFFA: ${ffa_standards}\nObjectives: ${learning_objectives}\nWeight update: cw=${current_weight} • tw=${target_weight} • d=${entry_date}`
  → submit as `retrieval_query`

### SPAR run controls (Advanced, collapsible)
- [ ] “Send to SPAR Orchestrator” checkbox (default ON)
- [ ] Readonly `run_id` preview (client trace id) to correlate UI ↔ n8n
- [ ] Advanced routing: `route.intent` select (default `edu_context`)
- [ ] Vector tuning inputs: `vector.match_count` (default 6), `vector.min_similarity` (default 0.75)
- [ ] Tool inputs override (optional): `tool_inputs.category`, `tool_inputs.query` (defaults to retrieval_query)

### Validation (before submit)
- [ ] Block submit if `user_id` or `animal_id` missing
- [ ] Block submit if `entry_text` empty
- [ ] Warn if `entry_date` missing; allow continue with today
- [ ] If weather fetch attempted and fails, proceed without weather but log warning

### Review & confirm
- [ ] “Preview assessment” area (read-only once SPAR returns)
- [ ] Save returned assessment JSON alongside entry (server-side), display:
      score, competencies, strengths, growth, recommendations

### Timeline & telemetry
- [ ] Timeline card shows weather pill (temp/wind/code) when present
- [ ] Persist a client `trace_id` with submission for observability
- [ ] Toasts: submitted → processing → stored (journal) → logged (spar_runs)

### Post-submit persistence (table mapping)
- [ ] Upsert `journal_entries` with: user_id, animal_id, title, entry_text,
      entry_date, category, duration_minutes, ffa_standards[], learning_objectives[],
      metadata{source,notes,location,weather}, (optional) quality_score
- [ ] Insert into `spar_runs`: run_id, user_id, goal, inputs (journal+meta+retrieval_query),
      plan, step_results, reflections, status
- [ ] Store assessment to `journal_entry_ai_assessments` (server-side) with normalized fields:
      overall_quality_score, justification, ffa_competencies_demonstrated[],
      learning_objectives_achieved[], strengths[], growth_opportunities[],
      personalized_recommendations[], career_pathway_connections[]


