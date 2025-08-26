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

- [] The Netlify deploy errored, with the following guidance provided:

**Diagnosis:**
The build failure is due to multiple errors in the `journal_entry_form_page.dart` file starting from line 3815 to line 4174. These errors include unmatched parenthesis and square brackets, duplicate function declarations, and conflicting imports.

**Solution:**
1. **Unmatched Parenthesis and Square Brackets:**
   - Fix the unmatched parenthesis and square brackets in the `journal_entry_form_page.dart` file starting from line 3815 to line 4174.

2. **Duplicate Function Declarations:**
   - Remove or rename the duplicate function declarations in the `journal_entry_form_page.dart` file to resolve the conflicts.

3. **Conflicting Imports:**
   - Address the conflicting imports of `JournalCategories` and `FFAConstants` from different files in the `journal_entry_form_page.dart` file to avoid naming conflicts.

E

# Feeds on Journal Entry — Task Backlog

**Goal:** Add a “Feeds” section to the Journal Entry flow so users can record feeds by **brand** (e.g., Jacoby) and **feed name** (e.g., Red Tag Sheep & Goat Developer), log **quantity** (feeds in **lbs**, hay in **flakes**), and quickly **Use Last** to auto-fill.  
**DB:** Uses the updated schema (`feed_brands`, `feed_products`, `journal_feed_items`, `user_feed_recent`) with RLS in place.

---

## Context & Assumptions

- `feed_brands(id, name, is_active, created_at)`
- `feed_products(id, brand_id, name, species text[], type text, is_active, created_at)`
  - Unique per brand on `(brand_id, lower(name))`.
- `journal_feed_items(id, entry_id, brand_id?, product_id?, is_hay bool, quantity numeric, unit text, note?, created_at)`
  - Constraint: `is_hay=true` ⇒ `unit='flakes'` & `brand_id/product_id` **null**; else `is_hay=false` ⇒ `unit='lbs'` & `product_id` **not null**.
- `user_feed_recent(user_id pk, brand_id?, product_id?, is_hay, quantity, unit, updated_at)`
- RLS:
  - `journal_feed_items`: owner-only via parent `journal_entries.user_id = auth.uid()`
  - `user_feed_recent`: `user_id = auth.uid()`
- Brands catalog should include: **Purina, Jacoby, Sunglo, Lindner, ADM/MoorMan’s ShowTec, Nutrena, Bluebonnet, Kalmbach, Umbarger, Show String**.
- Products seeded per brand/species (MVP set; can expand later).

---

## EPIC: Journal Entry — Feeds

### [FEEDS-001] Catalog: Complete brand & product seeding
**Type:** data  
**Priority:** P1  
**Estimate:** 0.5–1 day  
**Owner:** BE  
**AC:**
- [ ] These brands exist and are active: Purina, Jacoby, Sunglo, Lindner, ADM/MoorMan’s ShowTec, Nutrena, Bluebonnet, Kalmbach, Umbarger, Show String.
- [ ] Each brand has 3–6 representative products mapped to `species` (`goat|sheep|swine|cattle`) and `type` (`feed|mineral|supplement`).
- [ ] Product uniqueness per brand enforced (case-insensitive).
- [ ] PostgREST schema reloaded (`notify pgrst, 'reload schema';`).

**Notes:**
- Use a single idempotent seed script (`on conflict ... do update set is_active=true`).
- Keep names ASCII or use dollar-quoted strings to avoid editor quoting issues.

---

### [FEEDS-002] Read APIs: Brands & products (with species filter)
**Type:** backend  
**Priority:** P1  
**Estimate:** 0.5 day  
**Owner:** BE  
**AC:**
- [ ] Brands endpoint/query: `select id,name from feed_brands where is_active order by name;`
- [ ] Products endpoint/query supports brand and optional species filter:
  - SQL: `select id,name,species,type from feed_products where is_active and brand_id = :brand and (:species is null or :species = any(species)) order by name;`
  - REST (PostgREST) example:  
    `/rest/v1/feed_products?select=id,name,species,type&is_active=eq.true&brand_id=eq.<uuid>&species=cs.{goat}`
- [ ] Dart example provided to FE (see FEEDS-005).

---

### [FEEDS-003] “Use Last” read
**Type:** backend  
**Priority:** P1  
**Estimate:** 0.25 day  
**Owner:** BE  
**AC:**
- [ ] Query returns a single memory for `auth.uid()`:  
  `select brand_id,product_id,is_hay,quantity,unit from user_feed_recent where user_id = auth.uid();`
- [ ] When present, FE can fully prefill the modal; when absent, FE disables **Use Last**.

---

### [FEEDS-004] Feeds card UI (Journal Entry)
**Type:** frontend  
**Priority:** P1  
**Estimate:** 1 day  
**Owner:** FE  
**AC:**
- [ ] Card titled **Feed Data** shows empty state “No feeds selected.”
- [ ] Buttons: **+ Add Feed**, **Use Last** (disabled if no memory).
- [ ] List of feed tiles with edit/remove actions.
- [ ] “Required” indicator if no feed lines and entry demands nutrition logging.

---

### [FEEDS-005] Add Feed modal (hay toggle, dependent selects, quantity)
**Type:** frontend  
**Priority:** P1  
**Estimate:** 1.5–2 days  
**Owner:** FE  
**AC:**
- [ ] **Is Hay?** checkbox:
  - If checked: show **Quantity (flakes)** (integer or 0.5 increments per spec), hide brand/product, lock `unit='flakes'`.
  - If unchecked: show **Brand** (searchable) ⇒ **Feed Name** (searchable; filtered by Brand and optionally by species), **Quantity (lbs)** (step 0.25, default 1.0), lock `unit='lbs'`.
- [ ] Submitting adds/updates a tile:
  - Feed: `Brand — Product · {qty} lbs`
  - Hay: `Hay · {flakes} flakes`
- [ ] Modal supports Edit (prefill) and Cancel.

**Dart data access (example):**
```dart
final brands = await supabase
  .from('feed_brands')
  .select('id,name')
  .eq('is_active', true)
  .order('name');

final query = supabase
  .from('feed_products')
  .select('id,name,species,type')
  .eq('is_active', true)
  .eq('brand_id', brandId); // brandId = selected brand UUID

if (species != null && species.isNotEmpty) {
  query.contains('species', [species]); // e.g., ['goat']
}

final products = await query.order('name');


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

- [ ] **Fix Netlify deployment error** - Build failure in journal_entry_form_page.dart:
  - Lines 3815-4174 have syntax errors
  - Unmatched parentheses and brackets
  - Duplicate function declarations
  - Conflicting imports (JournalCategories, FFAConstants)

## Remaining Tasks 📋

### Post-submit Persistence (Verification Needed)
- [ ] Verify `journal_entries` upsert is working correctly with all fields
- [ ] Confirm server-side assessment storage in `journal_entry_ai_assessments`
- [ ] Validate that SPAR results are properly stored when N8N completes

### UI Completions
- [ ] Complete weather pill display on timeline (API integration needed)
- [ ] Implement assessment preview UI component
- [ ] Add visual indicators for AI processing status
