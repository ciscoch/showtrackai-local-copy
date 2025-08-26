import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../lib/services/journal_service.dart';
import '../../lib/services/n8n_webhook_service.dart';
import '../../lib/services/offline_storage_manager.dart';
import '../../lib/services/coppa_service.dart';
import '../../lib/models/journal_entry.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  Session,
  User,
  http.Client,
])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Journal → N8N → Supabase Integration Flow', () {
    late JournalService journalService;
    late N8NWebhookService webhookService;
    late OfflineStorageManager offlineManager;
    late CoppaService coppaService;
    
    // Test data
    const String testUserId = 'integration_test_user_123';
    const String testAnimalId = 'test_animal_456';
    const String webhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d';
    
    setUpAll(() async {
      // Initialize services
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );
      
      journalService = JournalService();
      webhookService = N8NWebhookService(webhookUrl: webhookUrl);
      offlineManager = OfflineStorageManager();
      coppaService = CoppaService();
      
      // Clean up any existing test data
      await _cleanupTestData();
    });

    tearDownAll(() async {
      // Clean up test data
      await _cleanupTestData();
    });

    test('Complete journal entry creation and AI processing flow', () async {
      // Step 1: Create a comprehensive journal entry
      final journalEntry = JournalEntry(
        id: null, // Will be generated
        userId: testUserId,
        title: 'Integration Test: Daily Health Check',
        description: '''
          Performed comprehensive health check on Holstein heifer #247.
          Temperature: 101.5°F (normal range)
          Heart rate: 60 bpm
          Respiratory rate: 30 breaths/minute
          Body condition score: 3.5/5
          
          Observations:
          - Clear eyes, no discharge
          - Good appetite, consumed all morning feed
          - Active and alert behavior
          - No signs of lameness or discomfort
          
          Actions taken:
          - Administered scheduled dewormer
          - Updated vaccination record
          - Recorded weight: 850 lbs
          
          Next steps:
          - Schedule hoof trimming for next week
          - Monitor weight gain progress
        ''',
        date: DateTime.now(),
        duration: 45,
        category: 'health_check',
        aetSkills: [
          'Animal Health Management',
          'Veterinary Care',
          'Record Keeping',
          'Data Analysis',
        ],
        animalId: testAnimalId,
        qualityScore: null, // Will be set by AI
        countsForDegree: true,
        financialValue: 125.00, // Vet supplies cost
        location: {
          'latitude': 40.4237,
          'longitude': -86.9212,
          'city': 'West Lafayette',
          'state': 'IN',
          'address': 'Test Farm, Agricultural Valley',
        },
        weather: {
          'temperature': 68.0,
          'condition': 'Partly Cloudy',
          'humidity': 55,
          'windSpeed': 8.5,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Step 2: Test COPPA compliance check
      final coppaCompliant = await coppaService.checkCompliance(testUserId);
      expect(coppaCompliant, isTrue, reason: 'User should be COPPA compliant');

      // Step 3: Create journal entry through service
      final createdEntry = await journalService.createEntry(journalEntry);
      
      // Verify entry was created
      expect(createdEntry.id, isNotNull, reason: 'Entry should have an ID');
      expect(createdEntry.userId, equals(testUserId));
      expect(createdEntry.title, equals(journalEntry.title));
      
      // Step 4: Trigger AI processing through N8N webhook
      print('Sending to N8N webhook for AI processing...');
      final aiResponse = await webhookService.sendToWebhook(createdEntry);
      
      // Verify AI response
      expect(aiResponse, isNotNull, reason: 'Should receive AI response');
      expect(aiResponse['status'], anyOf(['completed', 'fallback']),
          reason: 'AI processing should complete or fallback');
      
      if (aiResponse['status'] == 'completed') {
        // Verify AI insights
        expect(aiResponse['qualityScore'], greaterThanOrEqualTo(7),
            reason: 'Detailed entry should have high quality score');
        expect(aiResponse['ffaStandards'], isNotEmpty,
            reason: 'Should identify FFA standards');
        expect(aiResponse['ffaStandards'], contains('AS.07.01'),
            reason: 'Should identify animal health standard');
        
        // Verify educational insights
        expect(aiResponse['educationalConcepts'], isNotEmpty);
        expect(aiResponse['educationalConcepts'], 
            anyElement(contains('Health')),
            reason: 'Should identify health concepts');
        
        // Verify AI feedback
        final aiInsights = aiResponse['aiInsights'];
        expect(aiInsights, isNotNull);
        expect(aiInsights['feedback']['strengths'], isNotEmpty,
            reason: 'Should identify strengths');
        expect(aiInsights['recommendations'], isNotEmpty,
            reason: 'Should provide recommendations');
      }
      
      // Step 5: Update entry with AI results
      final updatedEntry = createdEntry.copyWith(
        qualityScore: aiResponse['qualityScore'] ?? 7,
        aiAnalysis: aiResponse,
      );
      
      final savedEntry = await journalService.updateEntry(updatedEntry);
      expect(savedEntry.qualityScore, isNotNull,
          reason: 'Quality score should be saved');
      
      // Step 6: Test retrieval
      final retrievedEntry = await journalService.getEntry(savedEntry.id!);
      expect(retrievedEntry, isNotNull);
      expect(retrievedEntry!.id, equals(savedEntry.id));
      expect(retrievedEntry.qualityScore, equals(savedEntry.qualityScore));
      
      // Step 7: Test search functionality
      final searchResults = await journalService.searchEntries(
        query: 'Holstein health check',
      );
      expect(searchResults, isNotEmpty,
          reason: 'Should find entry through search');
      expect(searchResults.any((e) => e.id == savedEntry.id), isTrue,
          reason: 'Created entry should be in search results');
      
      // Step 8: Test statistics calculation
      final stats = await journalService.getUserStats();
      expect(stats.totalEntries, greaterThan(0));
      expect(stats.totalHours, greaterThan(0));
      expect(stats.ffaDegreeEntries, greaterThan(0));
      
      // Store entry ID for cleanup
      _testEntryIds.add(savedEntry.id!);
    });

    test('Offline → Online sync with N8N processing', () async {
      // Step 1: Simulate offline mode
      await offlineManager.setOfflineMode(true);
      
      // Step 2: Create entry while offline
      final offlineEntry = JournalEntry(
        id: null,
        userId: testUserId,
        title: 'Offline Entry Test',
        description: 'Entry created while offline for testing sync',
        date: DateTime.now(),
        duration: 15,
        category: 'daily_care',
        aetSkills: ['Animal Care'],
        animalId: testAnimalId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final created = await journalService.createEntry(offlineEntry);
      expect(created.isSynced, isFalse,
          reason: 'Entry should not be synced while offline');
      
      // Step 3: Verify entry is in offline queue
      final queuedItems = await offlineManager.getQueuedItems();
      expect(queuedItems, isNotEmpty,
          reason: 'Entry should be queued for sync');
      
      // Step 4: Simulate coming back online
      await offlineManager.setOfflineMode(false);
      
      // Step 5: Trigger sync
      print('Syncing offline entries...');
      final syncSuccess = await journalService.syncOfflineEntries();
      expect(syncSuccess, isTrue,
          reason: 'Sync should complete successfully');
      
      // Step 6: Verify entry was synced and processed
      await Future.delayed(const Duration(seconds: 2)); // Wait for processing
      
      final syncedEntry = await journalService.getEntry(created.id!);
      expect(syncedEntry, isNotNull);
      expect(syncedEntry!.isSynced, isTrue,
          reason: 'Entry should be marked as synced');
      
      // Step 7: Verify N8N processing occurred
      final aiAnalysis = await webhookService.getCachedAnalysis(created.id!);
      if (aiAnalysis != null) {
        expect(aiAnalysis['status'], isNotNull,
            reason: 'Should have processing status');
      }
      
      // Store for cleanup
      _testEntryIds.add(created.id!);
    });

    test('COPPA compliance flow for minor users', () async {
      // Step 1: Create minor user profile
      const minorUserId = 'minor_test_user_789';
      const parentEmail = 'parent@test.com';
      
      await coppaService.createMinorProfile(
        userId: minorUserId,
        birthDate: DateTime.now().subtract(const Duration(days: 365 * 10)), // 10 years old
        parentEmail: parentEmail,
      );
      
      // Step 2: Verify minor cannot create entries without consent
      final isCompliant = await coppaService.checkCompliance(minorUserId);
      expect(isCompliant, isFalse,
          reason: 'Minor without consent should not be compliant');
      
      // Step 3: Simulate parent consent
      await coppaService.grantParentConsent(
        childId: minorUserId,
        parentEmail: parentEmail,
        consentToken: 'test_consent_token',
      );
      
      // Step 4: Verify minor can now create entries
      final isCompliantAfter = await coppaService.checkCompliance(minorUserId);
      expect(isCompliantAfter, isTrue,
          reason: 'Minor with consent should be compliant');
      
      // Step 5: Create entry as minor with consent
      final minorEntry = JournalEntry(
        id: null,
        userId: minorUserId,
        title: 'Minor User Entry',
        description: 'Entry created by minor with parent consent',
        date: DateTime.now(),
        duration: 20,
        category: 'daily_care',
        aetSkills: ['Animal Care'],
        animalId: testAnimalId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final createdMinorEntry = await journalService.createEntry(minorEntry);
      expect(createdMinorEntry.id, isNotNull,
          reason: 'Minor with consent should create entry');
      
      // Step 6: Test N8N processing with age-appropriate content
      final aiResponse = await webhookService.sendToWebhook(
        createdMinorEntry,
        userContext: {
          'ageGroup': 'child',
          'isMinor': true,
          'hasParentConsent': true,
        },
      );
      
      if (aiResponse['status'] == 'completed') {
        expect(aiResponse['coppaCompliant'], isTrue,
            reason: 'Response should be COPPA compliant');
        
        // Verify age-appropriate language in feedback
        final feedback = aiResponse['aiInsights']['feedback'];
        expect(feedback['language'], equals('age-appropriate'),
            reason: 'Should use age-appropriate language');
      }
      
      // Store for cleanup
      _testEntryIds.add(createdMinorEntry.id!);
      _testUserIds.add(minorUserId);
    });

    test('Error handling and recovery', () async {
      // Test 1: Invalid data handling
      final invalidEntry = JournalEntry(
        id: null,
        userId: '', // Invalid empty user ID
        title: 'Invalid Entry',
        description: 'Test',
        date: DateTime.now(),
        duration: 10,
        category: 'daily_care',
        aetSkills: [],
        animalId: testAnimalId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(
        () async => await journalService.createEntry(invalidEntry),
        throwsException,
        reason: 'Should throw exception for invalid data',
      );
      
      // Test 2: Network timeout recovery
      final timeoutEntry = JournalEntry(
        id: null,
        userId: testUserId,
        title: 'Timeout Test Entry',
        description: 'Testing timeout handling',
        date: DateTime.now(),
        duration: 10,
        category: 'daily_care',
        aetSkills: ['Animal Care'],
        animalId: testAnimalId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Simulate timeout by using very short timeout
      final response = await webhookService.sendToWebhook(
        timeoutEntry,
        timeout: const Duration(milliseconds: 1), // Extremely short timeout
      );
      
      expect(response['status'], equals('fallback'),
          reason: 'Should fallback on timeout');
      expect(response['source'], equals('local'),
          reason: 'Should use local analysis on timeout');
      
      // Test 3: Retry queue processing
      final retrySuccess = await webhookService.processRetryQueue();
      expect(retrySuccess, greaterThanOrEqualTo(0),
          reason: 'Retry queue processing should complete');
    });

    test('Performance and load testing', () async {
      // Create multiple entries rapidly
      final entries = <JournalEntry>[];
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 10; i++) {
        final entry = JournalEntry(
          id: null,
          userId: testUserId,
          title: 'Performance Test Entry $i',
          description: 'Testing system performance with rapid entry creation',
          date: DateTime.now(),
          duration: 10,
          category: 'daily_care',
          aetSkills: ['Animal Care'],
          animalId: testAnimalId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        entries.add(entry);
      }
      
      // Create all entries in parallel
      final createFutures = entries.map((e) => journalService.createEntry(e));
      final createdEntries = await Future.wait(createFutures);
      
      stopwatch.stop();
      
      // Verify performance
      expect(createdEntries, hasLength(10),
          reason: 'All entries should be created');
      expect(stopwatch.elapsedMilliseconds, lessThan(10000),
          reason: 'Should create 10 entries in under 10 seconds');
      
      print('Created ${createdEntries.length} entries in ${stopwatch.elapsedMilliseconds}ms');
      
      // Store for cleanup
      for (final entry in createdEntries) {
        if (entry.id != null) {
          _testEntryIds.add(entry.id!);
        }
      }
      
      // Test batch AI processing
      final aiProcessingStopwatch = Stopwatch()..start();
      final aiFutures = createdEntries
          .take(3) // Process first 3 to avoid rate limiting
          .map((e) => webhookService.sendToWebhook(e));
      
      final aiResponses = await Future.wait(aiFutures);
      aiProcessingStopwatch.stop();
      
      print('Processed ${aiResponses.length} entries through AI in ${aiProcessingStopwatch.elapsedMilliseconds}ms');
      
      // Verify all got responses (either success or fallback)
      for (final response in aiResponses) {
        expect(response['status'], anyOf(['completed', 'fallback']),
            reason: 'Each entry should get a response');
      }
    });
  });
}

// Test data cleanup
final Set<String> _testEntryIds = {};
final Set<String> _testUserIds = {};

Future<void> _cleanupTestData() async {
  try {
    final supabase = Supabase.instance.client;
    
    // Delete test journal entries
    if (_testEntryIds.isNotEmpty) {
      await supabase
          .from('journal_entries')
          .delete()
          .in_('id', _testEntryIds.toList());
    }
    
    // Delete test user profiles
    if (_testUserIds.isNotEmpty) {
      await supabase
          .from('user_profiles')
          .delete()
          .in_('id', _testUserIds.toList());
    }
    
    // Clear test data from local storage
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => 
      key.startsWith('test_') || 
      key.contains('integration_test')
    );
    
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    print('Test data cleanup completed');
  } catch (e) {
    print('Error during test cleanup: $e');
  }
}

// Extension for testing
extension JournalEntryTestExtension on JournalEntry {
  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? date,
    int? duration,
    String? category,
    List<String>? aetSkills,
    String? animalId,
    int? qualityScore,
    bool? countsForDegree,
    double? financialValue,
    Map<String, dynamic>? location,
    Map<String, dynamic>? weather,
    Map<String, dynamic>? aiAnalysis,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      aetSkills: aetSkills ?? this.aetSkills,
      animalId: animalId ?? this.animalId,
      qualityScore: qualityScore ?? this.qualityScore,
      countsForDegree: countsForDegree ?? this.countsForDegree,
      financialValue: financialValue ?? this.financialValue,
      location: location ?? this.location,
      weather: weather ?? this.weather,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}