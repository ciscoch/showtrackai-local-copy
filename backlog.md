# Backlog (Flutter Web)

## Completed Tasks ✅

### Initial Setup & Authentication
- [x] Fix authentication token handling ✅
- [x] Add COPPA compliance for minors ✅
- [x] Implement input validation ✅
- [x] Add offline storage limits ✅
- [x] Create comprehensive tests ✅
- [x] Animal create page (name, tag) ✅
- [x] Journal entry form with weather + geolocation ✅
- [x] Supabase RLS (owner only) ✅
- [x] Connect journal to n8n workflow at https://showtrackai.app.n8n.cloud/workflow/IA4KVsPotkhtYfW8 ✅
- [x] Push to git code_automation branch on https://github.com/ciscoch/showtrackai-local-copy.git do not merge to main ✅
- [x] Fix supabase authentication error: main.dart.js:101168 ✅
- [x] Remove mock data. Use only real data in database. Do not use offline mode right now. ✅

### UI/UX — Journal Entry → SPAR Integration (Completed)

#### Core form fields (Journal payload → journal_entries)
- [x] User selector (required) → sets `user_id` ✅
- [x] Animal selector (required) → sets `animal_id` ✅
- [x] Title text input (default: "Journal Entry") → `title` ✅
- [x] Rich text / multiline input (required) → `entry_text` ✅
- [x] Date picker (YYYY-MM-DD) → `entry_date` ✅
- [x] Category select (training, feeding, health, show, general) → `category` ✅
- [x] Duration number (minutes) with stepper → `duration_minutes` ✅
- [x] FFA standards multi-select chips (e.g., AS.06.02, AS.07.01) → `ffa_standards[]` ✅
- [x] Learning objectives tokens/chips → `learning_objectives[]` ✅

#### Weight/feeding mini-panel (normalizes `feed_strategy`)
- [x] Current weight (number, lbs) → `feed_strategy.current_weight` ✅
- [x] Target weight (number, lbs) → `feed_strategy.target_weight` ✅
- [x] Target/next weigh-in date → `feed_strategy.weigh_in_date` ✅

#### Location & weather (best-effort)
- [x] Location widget (city, state) + hidden lat/lon when available → `location.{city,state,lat,lon}` ✅
- [x] "Attach weather" button (fills preview chip) → store compact JSON in `weather` ✅
- [x] "Use IP-based weather if GPS not granted" toggle → sets source hint ✅

#### Metadata & source
- [x] Source select (mobile_app, web_app, import, api) → `metadata.source` ✅
- [x] Optional notes textarea → `metadata.notes` ✅

#### Retrieval query (for vector + planner)
- [x] Hidden field auto-composed: `${entry_text}\nFFA: ${ffa_standards}\nObjectives: ${learning_objectives}\nWeight update: cw=${current_weight} • tw=${target_weight} • d=${entry_date}`
  → submit as `retrieval_query` ✅

#### SPAR run controls (Advanced, collapsible)
- [x] "Send to SPAR Orchestrator" checkbox (default ON) ✅
- [x] Readonly `run_id` preview (client trace id) to correlate UI ↔ n8n ✅
- [x] Advanced routing: `route.intent` select (default `edu_context`) ✅
- [x] Vector tuning inputs: `vector.match_count` (default 6), `vector.min_similarity` (default 0.75) ✅
- [x] Tool inputs override (optional): `tool_inputs.category`, `tool_inputs.query` (defaults to retrieval_query) ✅

#### Validation (before submit)
- [x] Block submit if `user_id` or `animal_id` missing ✅
- [x] Block submit if `entry_text` empty ✅
- [x] Warn if `entry_date` missing; allow continue with today ✅
- [x] If weather fetch attempted and fails, proceed without weather but log warning ✅

## Now




- [] SHO-5 https://linear.app/showtrackai/issue/SHO-5/i-cannot-save-edits-to-animals I cannot save edits to animals without error. 


#NOW






## Recently Completed Tasks ✅

### Core Infrastructure
- [x] **Trace ID for observability** - Implemented in journal_entry_form_page.dart:
  - Generated once per submission for end-to-end correlation
  - Persisted through entire SPAR/N8N flow
  - Used in logging for distributed tracing

- [x] **Toast notification system** - Full implementation in journal_toast_service.dart:
  - Multi-stage submission flow (Submitting → Success → Processing → Stored → AI Complete)
  - Error handling with retry capability
  - Action buttons for viewing entries/results
  - Complete visual feedback throughout journal submission

- [x] **SPAR runs persistence** - Complete service implementation:
  - SPARRunsService created with full lifecycle tracking
  - Database integration for spar_runs table
  - Status tracking: pending → processing → completed/failed
  - Metadata and error tracking

- [x] **N8N webhook integration** - Fully operational:
  - N8NWebhookService with retry logic
  - Payload building with all journal metadata
  - Integration with SPAR tracking
  - Error handling and fallback mechanisms

### Partial Implementations (Need Verification)

- [⚠️] **Weather pill on timeline** - Weather service exists but not fully integrated:
  - WeatherService stub created but API not configured
  - Weather data structure in place
  - UI integration needed for timeline display

- [⚠️] **Preview assessment area** - Structure exists but not visible:
  - Variables defined (_assessmentResult, _showAssessmentPreview)
  - SPARAssessmentResult type referenced but not defined
  - UI component needs to be created

## Current Active Task 🚧

- [] SHO-5 https://linear.app/showtrackai/issue/SHO-5/i-cannot-save-edits-to-animals I cannot save edits to animals without error. 


## Remaining Tasks 📋

### Post-submit Persistence (Verification Needed)
- [ ] Verify `journal_entries` upsert is working correctly with all fields
- [ ] Confirm server-side assessment storage in `journal_entry_ai_assessments`
- [ ] Validate that SPAR results are properly stored when N8N completes

### UI Completions
- [ ] Complete weather pill display on timeline (API integration needed)
- [ ] Implement assessment preview UI component
- [ ] Add visual indicators for AI processing status
