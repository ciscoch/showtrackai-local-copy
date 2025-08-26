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

Ensure these changes are made in the mentioned file to resolve the build failure.

The relevant error logs are:

Line 260: Compiling lib/main.dart for the Web...
Line 261: Warning: In flutter_bootstrap.js:117: "FlutterLoader.loadEntrypoint" is deprecated. Use "FlutterLoader.load" instead. See https:
Line 262: Warning: In index.html:57: "FlutterLoader.loadEntrypoint" is deprecated. Use "FlutterLoader.load" instead. See https://docs.flut
Line 263: Wasm dry run findings:
Line 264: Found incompatibilities with WebAssembly.
Line 265: package:geolocator_web/src/html_geolocation_manager.dart 1:1 - dart:html unsupported (0)
Line 266: package:geolocator_web/src/html_permissions_manager.dart 1:1 - dart:html unsupported (0)
Line 267: package:geolocator_web/src/utils.dart 2:1 - dart:html unsupported (0)
Line 268: Consider addressing these issues to enable wasm builds. See docs for more info: https://docs.flutter.dev/platform-integration/we
Line 269: Use --no-wasm-dry-run to disable these warnings.
Line 270: Target dart2js failed: ProcessException: Process exited abnormally with exit code 1:
Line 271: lib/screens/journal_entry_form_page.dart:3816:17:
Line 272: Error: Can't find ']' to match '['.
      children: [
Line 273:                 ^
Line 274: lib/screens/journal_entry_form_page.dart:3815:18:
Line 275: Error: Can't find ')' to match '('.
    return Column(
Line 276:                  ^
Line 277: lib/screens/journal_entry_form_page.dart:690:16:
Line 278: Error: '_submitJournal' is already declared in this scope.
Line 279:   Future<void> _submitJournal() async {
Line 280:                ^^^^^^^^^^^^^^
Line 281: lib/screens/journal_entry_form_page.dart:667:16:
Line 282: Info: Previous declaration of '_submitJournal'.
Line 283:   Future<void> _submitJournal() async {
Line 284:                ^^^^^^^^^^^^^^
Line 285: lib/screens/journal_entry_form_page.dart:4055:12:
Line 286: Error: '_getAnimalIcon' is already declared in this scope.
Line 287:   IconData _getAnimalIcon(AnimalSpecies species) {
Line 288:            ^^^^^^^^^^^^^^
Line 289: lib/screens/journal_entry_form_page.dart:924:12:
Line 290: Info: Previous declaration of '_getAnimalIcon'.
Line 291:   IconData _getAnimalIcon(String species) {
Line 292:            ^^^^^^^^^^^^^^
Line 293: lib/screens/journal_entry_form_page.dart:4314:10:
Line 294: Error: '_buildAssessmentPreview' is already declared in this scope.
Line 295:   Widget _buildAssessmentPreview() {
Line 296:          ^^^^^^^^^^^^^^^^^^^^^^^
Line 297: lib/screens/journal_entry_form_page.dart:3294:10:
Line 298: Info: Previous declaration of '_buildAssessmentPreview'.
Line 299:   Widget _buildAssessmentPreview() {
Line 300:          ^^^^^^^^^^^^^^^^^^^^^^^
Line 301: lib/screens/journal_entry_form_page.dart:4307:8:
Line 302: Error: '_simulateAssessmentResult' is already declared in this scope.
Line 303:   void _simulateAssessmentResult() {
Line 304:        ^^^^^^^^^^^^^^^^^^^^^^^^^
Line 305: lib/screens/journal_entry_form_page.dart:3797:8:
Line 306: Info: Previous declaration of '_simulateAssessmentResult'.
Line 307:   void _simulateAssessmentResult() {
Line 308:        ^^^^^^^^^^^^^^^^^^^^^^^^^
Line 309: lib/screens/journal_entry_form_page.dart:4098:10:
Line 310: Error: '_buildSubmitButton' is already declared in this scope.
Line 311:   Widget _buildSubmitButton() {
Line 312:          ^^^^^^^^^^^^^^^^^^
Line 313: lib/screens/journal_entry_form_page.dart:3814:10:
Line 314: Info: Previous declaration of '_buildSubmitButton'.
Line 315:   Widget _buildSubmitButton() {
Line 316:          ^^^^^^^^^^^^^^^^^^
Line 317: lib/screens/journal_entry_form_page.dart:4165:8:
Line 318: Error: '_showFFAStandardsDialog' is already declared in this scope.
Line 319:   void _showFFAStandardsDialog() {
Line 320:        ^^^^^^^^^^^^^^^^^^^^^^^
Line 321: lib/screens/journal_entry_form_page.dart:3907:8:
Line 322: Info: Previous declaration of '_showFFAStandardsDialog'.
Line 323:   void _showFFAStandardsDialog() {
Line 324:        ^^^^^^^^^^^^^^^^^^^^^^^
Line 325: lib/screens/journal_entry_form_page.dart:4206:8:
Line 326: Error: '_showAETSkillsDialog' is already declared in this scope.
Line 327:   void _showAETSkillsDialog() {
Line 328:        ^^^^^^^^^^^^^^^^^^^^
Line 329: lib/screens/journal_entry_form_page.dart:3948:8:
Line 330: Info: Previous declaration of '_showAETSkillsDialog'.
Line 331:   void _showAETSkillsDialog() {
Line 332:        ^^^^^^^^^^^^^^^^^^^^
Line 333: lib/screens/journal_entry_form_page.dart:4255:8:
Line 334: Error: '_showHelpDialog' is already declared in this scope.
Line 335:   void _showHelpDialog() {
Line 336:        ^^^^^^^^^^^^^^^
Line 337: lib/screens/journal_entry_form_page.dart:3989:8:
Line 338: Info: Previous declaration of '_showHelpDialog'.
Line 339:   void _showHelpDialog() {
Line 340:        ^^^^^^^^^^^^^^^
Line 341: lib/screens/journal_entry_form_page.dart:1382:14:
Line 342: Error: 'JournalCategories' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtra
Line 343:       items: JournalCategories.categories.map((category) {
Line 344:              ^^^^^^^^^^^^^^^^^
Line 345: lib/screens/journal_entry_form_page.dart:1389:20:
Line 346: Error: 'JournalCategories' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtra
Line 347:               Text(JournalCategories.getDisplayName(category)),
Line 348:                    ^^^^^^^^^^^^^^^^^
Line 349: lib/screens/journal_entry_form_page.dart:2578:22:
Line 350: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 351:               items: FFAConstants.degreeTypes.map((type) {
Line 352:                      ^^^^^^^^^^^^
Line 353: lib/screens/journal_entry_form_page.dart:2594:22:
Line 354: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 355:               items: FFAConstants.saeTypes.map((type) {
Line 356:                      ^^^^^^^^^^^^
Line 357: lib/screens/journal_entry_form_page.dart:2650:22:
Line 358: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 359:               items: FFAConstants.evidenceTypes.map((type) {
Line 360:                      ^^^^^^^^^^^^
Line 361: lib/screens/journal_entry_form_page.dart:3607:26:
Line 362: Error: The getter 'shade700' isn't defined for the type 'Color'.
 - 'Color' is from 'dart:ui'.
Line 363:             color: color.shade700,
Line 364:                          ^^^^^^^^
Line 365: lib/screens/journal_entry_form_page.dart:4174:23:
Line 366: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 367:             children: FFAConstants.animalSystemsStandards.map((standard) {
Line 368:                       ^^^^^^^^^^^^
Line 369: lib/widgets/toast_notification_widget.dart:126:21:
Line 370: Error: The getter 'SemanticsRole' isn't defined for the type '_ToastWidgetState'.
 - '_ToastWidgetState' is from 'package:showtr
Line 371:               role: SemanticsRole.statusBar,
Line 372:                     ^^^^^^^^^^^^^
Line 373: lib/services/feed_service.dart:721:12:
Line 374: Error: The method 'in_' isn't defined for the type 'PostgrestFilterBuilder<List<Map<String, dynamic>>>'.
 - 'PostgrestFilterBuil
Line 375:  - 'List' is from 'dart:core'.
Line 376:  - 'Map' is from 'dart:core'.
Line 377:           .in_('name', productNames)
Line 378:            ^^^
Line 379: lib/widgets/feed_data_card.dart:586:25:
Line 380: Error: The argument type 'AnimalSpecies?' can't be assigned to the parameter type 'String?'.
 - 'AnimalSpecies' is from 'package
Line 381:         species: widget.selectedAnimal?.species,
Line 382:                         ^
Line 383: lib/services/spar_runs_service.dart:85:27:
Line 384: Error: A value of type 'Map<String, dynamic>' can't be assigned to a variable of type 'String'.
 - 'Map' is from 'dart:core'.
Line 385:         updates['plan'] = plan;
Line 386:                           ^
Line 387: lib/services/spar_runs_service.dart:295:52:
Line 388: Error: Operator '/' cannot be called on 'num?' because it is potentially null.
Line 389:         stats['success_rate'] = stats['completed'] / runs.length;
Line 390:                                                    ^
Line 391: lib/services/spar_runs_service.dart:360:12:
Line 392: Error: The method 'in_' isn't defined for the type 'PostgrestFilterBuilder<dynamic>'.
 - 'PostgrestFilterBuilder' is from 'packa
Line 393:           .in_('status', statusesToClean)
Line 394:            ^^^
Line 395: lib/services/spar_runs_service.dart:437:12:
Line 396: Error: The method 'in_' isn't defined for the type 'PostgrestFilterBuilder<List<Map<String, dynamic>>>'.
 - 'PostgrestFilterBuil
Line 397:  - 'List' is from 'dart:core'.
Line 398:  - 'Map' is from 'dart:core'.
Line 399:           .in_('status', [STATUS_PENDING, STATUS_PROCESSING])
Line 400:            ^^^
Line 401: Error: Compilation failed.
Line 402:   Command: /tmp/flutter_sdk_1881/flutter/bin/cache/dart-sdk/bin/dart compile js --platform-binaries=/tmp/flutter_sdk_1881/flutte
Line 403: #0      RunResult.throwException (package:flutter_tools/src/base/process.dart:118:5)
Line 404: #1      _DefaultProcessUtils.run (package:flutter_tools/src/base/process.dart:344:19)
Line 405: <asynchronous suspension>
Line 406: #2      Dart2JSTarget.build (package:flutter_tools/src/build_system/targets/web.dart:204:5)
Line 407: <asynchronous suspension>
Line 408: #3      _BuildInstance._invokeInternal (package:flutter_tools/src/build_system/build_system.dart:873:9)
Line 409: <asynchronous suspension>
Line 410: #4      Future.wait.<anonymous closure> (dart:async/future.dart:525:21)
Line 411: <asynchronous suspension>
Line 412: #5      _BuildInstance.invokeTarget (package:flutter_tools/src/build_system/build_system.dart:811:32)
Line 413: <asynchronous suspension>
Line 433: <asynchronous suspension>
Line 434: #16     FlutterCommandRunner.runCommand (package:flutter_tools/src/runner/flutter_command_runner.dart:438:5)
Line 435: <asynchronous suspension>
Line 436: #17     run.<anonymous closure>.<anonymous closure> (package:flutter_tools/runner.dart:98:11)
Line 437: <asynchronous suspension>
Line 438: #18     AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
Line 439: <asynchronous suspension>
Line 440: #19     main (package:flutter_tools/executable.dart:101:3)
Line 441: <asynchronous suspension>
Line 442: Compiling lib/main.dart for the Web...                              8.7s
Line 443: Error: Failed to compile application for the Web.
Line 444: ⚠️ Primary build failed. Retrying with minimal flags…
Line 445: Compiling lib/main.dart for the Web...
Line 446: Warning: In flutter_bootstrap.js:117: "FlutterLoader.loadEntrypoint" is deprecated. Use "FlutterLoader.load" instead. See https:
Line 447: Warning: In index.html:57: "FlutterLoader.loadEntrypoint" is deprecated. Use "FlutterLoader.load" instead. See https://docs.flut
Line 448: Wasm dry run findings:
Line 449: Found incompatibilities with WebAssembly.
Line 450: package:geolocator_web/src/html_geolocation_manager.dart 1:1 - dart:html unsupported (0)
Line 451: package:geolocator_web/src/html_permissions_manager.dart 1:1 - dart:html unsupported (0)
Line 452: package:geolocator_web/src/utils.dart 2:1 - dart:html unsupported (0)
Line 453: Consider addressing these issues to enable wasm builds. See docs for more info: https://docs.flutter.dev/platform-integration/we
Line 454: Use --no-wasm-dry-run to disable these warnings.
Line 455: Failed during stage 'building site': Build script returned non-zero exit code: 2
Line 456: Target dart2js failed: ProcessException: Process exited abnormally with exit code 1:
Line 457: lib/screens/journal_entry_form_page.dart:3816:17:
Line 458: Error: Can't find ']' to match '['.
      children: [
Line 459:                 ^
Line 460: lib/screens/journal_entry_form_page.dart:3815:18:
Line 461: Error: Can't find ')' to match '('.
    return Column(
Line 462:                  ^
Line 463: lib/screens/journal_entry_form_page.dart:690:16:
Line 464: Error: '_submitJournal' is already declared in this scope.
Line 465:   Future<void> _submitJournal() async {
Line 466:                ^^^^^^^^^^^^^^
Line 467: lib/screens/journal_entry_form_page.dart:667:16:
Line 468: Info: Previous declaration of '_submitJournal'.
Line 469:   Future<void> _submitJournal() async {
Line 470:                ^^^^^^^^^^^^^^
Line 471: lib/screens/journal_entry_form_page.dart:4055:12:
Line 472: Error: '_getAnimalIcon' is already declared in this scope.
Line 473:   IconData _getAnimalIcon(AnimalSpecies species) {
Line 474:            ^^^^^^^^^^^^^^
Line 475: lib/screens/journal_entry_form_page.dart:924:12:
Line 476: Info: Previous declaration of '_getAnimalIcon'.
Line 477:   IconData _getAnimalIcon(String species) {
Line 478:            ^^^^^^^^^^^^^^
Line 479: lib/screens/journal_entry_form_page.dart:4314:10:
Line 480: Error: '_buildAssessmentPreview' is already declared in this scope.
Line 481:   Widget _buildAssessmentPreview() {
Line 482:          ^^^^^^^^^^^^^^^^^^^^^^^
Line 483: lib/screens/journal_entry_form_page.dart:3294:10:
Line 484: Info: Previous declaration of '_buildAssessmentPreview'.
Line 485:   Widget _buildAssessmentPreview() {
Line 486:          ^^^^^^^^^^^^^^^^^^^^^^^
Line 487: lib/screens/journal_entry_form_page.dart:4307:8:
Line 488: Error: '_simulateAssessmentResult' is already declared in this scope.
Line 489:   void _simulateAssessmentResult() {
Line 490:        ^^^^^^^^^^^^^^^^^^^^^^^^^
Line 491: lib/screens/journal_entry_form_page.dart:3797:8:
Line 492: Info: Previous declaration of '_simulateAssessmentResult'.
Line 493:   void _simulateAssessmentResult() {
Line 494:        ^^^^^^^^^^^^^^^^^^^^^^^^^
Line 495: lib/screens/journal_entry_form_page.dart:4098:10:
Line 496: Error: '_buildSubmitButton' is already declared in this scope.
Line 497:   Widget _buildSubmitButton() {
Line 498:          ^^^^^^^^^^^^^^^^^^
Line 499: lib/screens/journal_entry_form_page.dart:3814:10:
Line 500: Info: Previous declaration of '_buildSubmitButton'.
Line 501:   Widget _buildSubmitButton() {
Line 502:          ^^^^^^^^^^^^^^^^^^
Line 503: lib/screens/journal_entry_form_page.dart:4165:8:
Line 504: Error: '_showFFAStandardsDialog' is already declared in this scope.
Line 505:   void _showFFAStandardsDialog() {
Line 506:        ^^^^^^^^^^^^^^^^^^^^^^^
Line 507: lib/screens/journal_entry_form_page.dart:3907:8:
Line 508: Info: Previous declaration of '_showFFAStandardsDialog'.
Line 509:   void _showFFAStandardsDialog() {
Line 510:        ^^^^^^^^^^^^^^^^^^^^^^^
Line 511: lib/screens/journal_entry_form_page.dart:4206:8:
Line 512: Error: '_showAETSkillsDialog' is already declared in this scope.
Line 513:   void _showAETSkillsDialog() {
Line 514:        ^^^^^^^^^^^^^^^^^^^^
Line 515: lib/screens/journal_entry_form_page.dart:3948:8:
Line 516: Info: Previous declaration of '_showAETSkillsDialog'.
Line 517:   void _showAETSkillsDialog() {
Line 518:        ^^^^^^^^^^^^^^^^^^^^
Line 519: lib/screens/journal_entry_form_page.dart:4255:8:
Line 520: Error: '_showHelpDialog' is already declared in this scope.
Line 521:   void _showHelpDialog() {
Line 522:        ^^^^^^^^^^^^^^^
Line 523: lib/screens/journal_entry_form_page.dart:3989:8:
Line 524: Info: Previous declaration of '_showHelpDialog'.
Line 525:   void _showHelpDialog() {
Line 526:        ^^^^^^^^^^^^^^^
Line 527: lib/screens/journal_entry_form_page.dart:1382:14:
Line 528: Error: 'JournalCategories' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtra
Line 529:       items: JournalCategories.categories.map((category) {
Line 530:              ^^^^^^^^^^^^^^^^^
Line 531: lib/screens/journal_entry_form_page.dart:1389:20:
Line 532: Error: 'JournalCategories' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtra
Line 533:               Text(JournalCategories.getDisplayName(category)),
Line 534:                    ^^^^^^^^^^^^^^^^^
Line 535: lib/screens/journal_entry_form_page.dart:2578:22:
Line 536: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 537:               items: FFAConstants.degreeTypes.map((type) {
Line 538:                      ^^^^^^^^^^^^
Line 539: lib/screens/journal_entry_form_page.dart:2594:22:
Line 540: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 541:               items: FFAConstants.saeTypes.map((type) {
Line 542:                      ^^^^^^^^^^^^
Line 543: lib/screens/journal_entry_form_page.dart:2650:22:
Line 544: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 545:               items: FFAConstants.evidenceTypes.map((type) {
Line 546:                      ^^^^^^^^^^^^
Line 547: lib/screens/journal_entry_form_page.dart:3607:26:
Line 548: Error: The getter 'shade700' isn't defined for the type 'Color'.
 - 'Color' is from 'dart:ui'.
Line 549:             color: color.shade700,
Line 550:                          ^^^^^^^^
Line 551: lib/screens/journal_entry_form_page.dart:4174:23:
Line 552: Error: 'FFAConstants' is imported from both 'package:showtrackai_journaling/models/ffa_constants.dart' and 'package:showtrackai_
Line 553:             children: FFAConstants.animalSystemsStandards.map((standard) {
Line 554:                       ^^^^^^^^^^^^
Line 555: lib/widgets/toast_notification_widget.dart:126:21:
Line 556: Error: The getter 'SemanticsRole' isn't defined for the type '_ToastWidgetState'.
 - '_ToastWidgetState' is from 'package:showtr
Line 557:               role: SemanticsRole.statusBar,
Line 558:                     ^^^^^^^^^^^^^
Line 559: lib/services/feed_service.dart:721:12:
Line 560: Error: The method 'in_' isn't defined for the type 'PostgrestFilterBuilder<List<Map<String, dynamic>>>'.
 - 'PostgrestFilterBuil
Line 561:  - 'List' is from 'dart:core'.
Line 562:  - 'Map' is from 'dart:core'.
Line 563:           .in_('name', productNames)
Line 564:            ^^^
Line 565: lib/widgets/feed_data_card.dart:586:25:
Line 566: Error: The argument type 'AnimalSpecies?' can't be assigned to the parameter type 'String?'.
 - 'AnimalSpecies' is from 'package
Line 567:         species: widget.selectedAnimal?.species,
Line 568:                         ^
Line 569: lib/services/spar_runs_service.dart:85:27:
Line 570: Error: A value of type 'Map<String, dynamic>' can't be assigned to a variable of type 'String'.
 - 'Map' is from 'dart:core'.
Line 571:         updates['plan'] = plan;
Line 572:                           ^
Line 573: lib/services/spar_runs_service.dart:295:52:
Line 574: Error: Operator '/' cannot be called on 'num?' because it is potentially null.
Line 575:         stats['success_rate'] = stats['completed'] / runs.length;
Line 576:                                                    ^
Line 577: lib/services/spar_runs_service.dart:360:12:
Line 578: Error: The method 'in_' isn't defined for the type 'PostgrestFilterBuilder<dynamic>'.
 - 'PostgrestFilterBuilder' is from 'packa
Line 579:           .in_('status', statusesToClean)
Line 580:            ^^^
Line 581: lib/services/spar_runs_service.dart:437:12:
Line 582: Error: The method 'in_' isn't defined for the type 'PostgrestFilterBuilder<List<Map<String, dynamic>>>'.
 - 'PostgrestFilterBuil
Line 583:  - 'List' is from 'dart:core'.
Line 584:  - 'Map' is from 'dart:core'.
Line 585:           .in_('status', [STATUS_PENDING, STATUS_PROCESSING])
Line 586:            ^^^
Line 587: Error: Compilation failed.
Line 588:   Command: /tmp/flutter_sdk_1881/flutter/bin/cache/dart-sdk/bin/dart compile js --platform-binaries=/tmp/flutter_sdk_1881/flutte
Line 589: #0      RunResult.throwException (package:flutter_tools/src/base/process.dart:118:5)
Line 590: #1      _DefaultProcessUtils.run (package:flutter_tools/src/base/process.dart:344:19)
Line 591: <asynchronous suspension>
Line 592: #2      Dart2JSTarget.build (package:flutter_tools/src/build_system/targets/web.dart:204:5)
Line 593: <asynchronous suspension>
Line 594: #3      _BuildInstance._invokeInternal (package:flutter_tools/src/build_system/build_system.dart:873:9)
Line 595: <asynchronous suspension>
Line 596: #4      Future.wait.<anonymous closure> (dart:async/future.dart:525:21)
Line 597: <asynchronous suspension>
Line 598: #5      _BuildInstance.invokeTarget (package:flutter_tools/src/build_system/build_system.dart:811:32)
Line 599: <asynchronous suspension>
Line 619: <asynchronous suspension>
Line 620: #16     FlutterCommandRunner.runCommand (package:flutter_tools/src/runner/flutter_command_runner.dart:438:5)
Line 621: <asynchronous suspension>
Line 622: #17     run.<anonymous closure>.<anonymous closure> (package:flutter_tools/runner.dart:98:11)
Line 623: <asynchronous suspension>
Line 624: #18     AppContext.run.<anonymous closure> (package:flutter_tools/src/base/context.dart:154:19)
Line 625: <asynchronous suspension>
Line 626: #19     main (package:flutter_tools/executable.dart:101:3)
Line 627: <asynchronous suspension>
Line 628: Compiling lib/main.dart for the Web...                              8.6s
Line 629: Error: Failed to compile application for the Web.
Line 630: ❌ Build failed
Line 631: [91m[1m​[22m[39m
Line 632: [91m[1m"build.command" failed                                        [22m[39m
Line 633: [91m[1m────────────────────────────────────────────────────────────────[22m[39m
Line 634: ​
Line 635:   [31m[1mError message[22m[39m
Line 636:   Command failed with exit code 1: ./build_for_netlify.sh
Line 637: ​
Line 638:   [31m[1mError location[22m[39m
Line 639:   In build.command from netlify.toml:
Line 640:   ./build_for_netlify.sh
Line 641: ​
Line 642:   [31m[1mResolved config[22m[39m
Line 643:   build:
Line 644:     command: ./build_for_netlify.sh
Line 645:     commandOrigin: config
Line 646:     environment:
Line 647:       - REVIEW_ID
Line 648:       - SUPABASE_ANON_KEY
Line 649:       - SUPABASE_DATABASE_URL
Line 650:       - SUPABASE_JWT_SECRET
Line 651:       - SUPABASE_SERVICE_ROLE_KEY
Line 652:       - SUPABASE_URL
Line 653:     publish: /opt/build/repo/build/web
Line 654:     publishOrigin: config
Line 655:   functionsDirectory: /opt/build/repo/netlify/functions
Line 656:   redirects:
Line 657:     - from: /*
      status: 200
      to: /index.html
  redirectsOrigin: config
Line 658: Build failed due to a user error: Build script returned non-zero exit code: 2
Line 659: Failing build: Failed to build site
Line 660: Finished processing build request in 1m4.236s

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
