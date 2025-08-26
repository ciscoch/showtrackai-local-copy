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


## Uncompleted Tasks 📋

### Review & Confirm
- [ ] "Preview assessment" area (read-only once SPAR returns)
- [ ] Save returned assessment JSON alongside entry (server-side), display:
      score, competencies, strengths, growth, recommendations

### Timeline & Telemetry
- [ ] Timeline card shows weather pill (temp/wind/code) when present
- [ ] Persist a client `trace_id` with submission for observability
- [ ] Toasts: submitted → processing → stored (journal) → logged (spar_runs)

### Post-submit Persistence (table mapping)
- [ ] Upsert `journal_entries` with: user_id, animal_id, title, entry_text,
      entry_date, category, duration_minutes, ffa_standards[], learning_objectives[],
      metadata{source,notes,location,weather}, (optional) quality_score
- [ ] Insert into `spar_runs`: run_id, user_id, goal, inputs (journal+meta+retrieval_query),
      plan, step_results, reflections, status
- [ ] Store assessment to `journal_entry_ai_assessments` (server-side) with normalized fields:
      overall_quality_score, justification, ffa_competencies_demonstrated[],
      learning_objectives_achieved[], strengths[], growth_opportunities[],
      personalized_recommendations[], career_pathway_connections[]
