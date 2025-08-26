import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/n8n_webhook_service.dart';
import '../../lib/models/journal_entry.dart';
import 'n8n_webhook_service_test.mocks.dart';

@GenerateMocks([
  http.Client,
  SharedPreferences,
])
void main() {
  group('N8NWebhookService Tests', () {
    late MockClient mockHttpClient;
    late MockSharedPreferences mockPrefs;
    late N8NWebhookService service;
    
    const String webhookUrl = 'https://showtrackai.app.n8n.cloud/webhook/test';
    const String testRequestId = 'webhook_test_123';
    
    setUp(() {
      mockHttpClient = MockClient();
      mockPrefs = MockSharedPreferences();
      SharedPreferences.setMockInitialValues({});
      
      service = N8NWebhookService(
        webhookUrl: webhookUrl,
        httpClient: mockHttpClient,
      );
    });

    group('sendToWebhook', () {
      test('should successfully send journal entry to webhook', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        final expectedResponse = _createSuccessfulWebhookResponse();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(expectedResponse),
          200,
        ));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(journalEntry);
        
        // Assert
        expect(result, isNotNull);
        expect(result['status'], equals('completed'));
        expect(result['qualityScore'], equals(8));
        
        // Verify webhook was called with correct payload structure
        verify(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: argThat(
            allOf(
              containsPair('Content-Type', 'application/json'),
              containsPair('X-Request-Id', contains('webhook_')),
            ),
            named: 'headers',
          ),
          body: argThat(
            allOf(
              contains('"journalEntry"'),
              contains('"userContext"'),
              contains('"processingOptions"'),
            ),
            named: 'body',
          ),
        )).called(1);
      });

      test('should retry on temporary failure with exponential backoff', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        final successResponse = _createSuccessfulWebhookResponse();
        
        // First two attempts fail, third succeeds
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Service Unavailable', 503))
           .thenAnswer((_) async => http.Response('Gateway Timeout', 504))
           .thenAnswer((_) async => http.Response(jsonEncode(successResponse), 200));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(journalEntry, maxRetries: 3);
        
        // Assert
        expect(result, isNotNull);
        expect(result['status'], equals('completed'));
        
        // Verify three attempts were made
        verify(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).called(3);
      });

      test('should fallback to local analysis after max retries', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        // All attempts fail
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response('Service Unavailable', 503));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(journalEntry, maxRetries: 2);
        
        // Assert
        expect(result, isNotNull);
        expect(result['status'], equals('fallback'));
        expect(result['source'], equals('local'));
        expect(result['qualityScore'], isNotNull);
        
        // Verify fallback analysis was performed
        expect(result['aiInsights'], isNotNull);
        expect(result['aiInsights']['feedback']['strengths'], isNotEmpty);
      });

      test('should handle network timeout gracefully', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) => Future.delayed(
          const Duration(seconds: 35), // Longer than timeout
          () => http.Response('Timeout', 408),
        ));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(
          journalEntry,
          timeout: const Duration(seconds: 5),
        );
        
        // Assert
        expect(result, isNotNull);
        expect(result['status'], equals('fallback'));
        expect(result['reason'], contains('timeout'));
      });

      test('should cache successful webhook responses', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        final successResponse = _createSuccessfulWebhookResponse();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(successResponse),
          200,
        ));

        when(mockPrefs.getString(any)).thenReturn(null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        await service.sendToWebhook(journalEntry);
        
        // Assert - Verify cache was set
        verify(mockPrefs.setString(
          argThat(contains('n8n_cache_')),
          argThat(contains('"status":"completed"')),
        )).called(1);
      });

      test('should use cached response when available and valid', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        final cachedResponse = {
          'status': 'completed',
          'qualityScore': 9,
          'cached': true,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        // Setup cache to return valid cached data
        when(mockPrefs.getString(argThat(contains('n8n_cache_'))))
            .thenReturn(jsonEncode(cachedResponse));
        
        // Act
        final result = await service.getCachedAnalysis(journalEntry.id!);
        
        // Assert
        expect(result, isNotNull);
        expect(result!['cached'], isTrue);
        expect(result['qualityScore'], equals(9));
        
        // Verify no HTTP call was made
        verifyNever(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')));
      });

      test('should queue failed requests for retry', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenThrow(const SocketException('Network unreachable'));

        when(mockPrefs.getStringList('n8n_retry_queue')).thenReturn([]);
        when(mockPrefs.setStringList('n8n_retry_queue', any))
            .thenAnswer((_) async => true);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        // Act
        await service.sendToWebhook(journalEntry);
        
        // Assert - Verify request was queued
        verify(mockPrefs.setStringList(
          'n8n_retry_queue',
          argThat(hasLength(1)),
        )).called(greaterThanOrEqualTo(1));
      });
    });

    group('processRetryQueue', () {
      test('should process queued webhook requests', () async {
        // Arrange
        final queuedRequest = {
          'requestId': 'queued_123',
          'journalEntryId': 'entry_123',
          'payload': _createTestJournalEntry().toJson(),
          'attempts': 1,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        when(mockPrefs.getStringList('n8n_retry_queue'))
            .thenReturn([jsonEncode(queuedRequest)]);
        when(mockPrefs.setStringList('n8n_retry_queue', any))
            .thenAnswer((_) async => true);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode(_createSuccessfulWebhookResponse()),
          200,
        ));
        
        // Act
        final processed = await service.processRetryQueue();
        
        // Assert
        expect(processed, equals(1));
        
        // Verify queue was cleared after successful processing
        verify(mockPrefs.setStringList('n8n_retry_queue', [])).called(1);
      });

      test('should respect max retry attempts in queue', () async {
        // Arrange
        final oldRequest = {
          'requestId': 'old_123',
          'journalEntryId': 'entry_123',
          'payload': _createTestJournalEntry().toJson(),
          'attempts': 5, // Already exceeded max attempts
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        };
        
        when(mockPrefs.getStringList('n8n_retry_queue'))
            .thenReturn([jsonEncode(oldRequest)]);
        when(mockPrefs.setStringList('n8n_retry_queue', any))
            .thenAnswer((_) async => true);
        
        // Act
        final processed = await service.processRetryQueue();
        
        // Assert
        expect(processed, equals(0));
        
        // Verify request was removed from queue without processing
        verify(mockPrefs.setStringList('n8n_retry_queue', [])).called(1);
        
        // Verify no HTTP call was made
        verifyNever(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')));
      });
    });

    group('performFallbackAnalysis', () {
      test('should generate meaningful local analysis', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry(
          description: 'Today I checked the health of my Holstein cow. Temperature was 101.5°F, which is normal. The cow showed good appetite and clear eyes. I administered the scheduled vaccination and updated the health records.',
          category: 'health_check',
          aetSkills: ['Animal Health Management', 'Veterinary Care'],
        );
        
        // Act
        final result = await service.performFallbackAnalysis(journalEntry);
        
        // Assert
        expect(result, isNotNull);
        expect(result['status'], equals('fallback'));
        expect(result['source'], equals('local'));
        expect(result['qualityScore'], greaterThanOrEqualTo(7)); // Health check with details
        
        // Verify AI insights structure
        expect(result['aiInsights'], isNotNull);
        expect(result['aiInsights']['qualityAssessment']['score'], greaterThanOrEqualTo(7));
        expect(result['aiInsights']['feedback']['strengths'], contains('Health monitoring'));
        
        // Verify FFA standards detection
        expect(result['ffaStandards'], contains('AS.07.01'));
        
        // Verify educational concepts
        expect(result['educationalConcepts'], contains('Animal Health'));
      });

      test('should adjust scoring based on entry completeness', () async {
        // Arrange
        final minimalEntry = _createTestJournalEntry(
          description: 'Fed the cow',
          category: 'daily_care',
          aetSkills: [],
        );
        
        final detailedEntry = _createTestJournalEntry(
          description: 'Conducted comprehensive health assessment. Checked temperature (101.5°F), heart rate (60 bpm), and respiratory rate (30 breaths/min). All vitals within normal range. Administered dewormer and updated vaccination schedule. Cow weight: 1200 lbs, body condition score: 3.5/5.',
          category: 'health_check',
          aetSkills: ['Animal Health Management', 'Data Recording', 'Medical Administration'],
          duration: 45,
        );
        
        // Act
        final minimalResult = await service.performFallbackAnalysis(minimalEntry);
        final detailedResult = await service.performFallbackAnalysis(detailedEntry);
        
        // Assert
        expect(minimalResult['qualityScore'], lessThan(5));
        expect(detailedResult['qualityScore'], greaterThanOrEqualTo(8));
        
        // Detailed entry should have more recommendations
        expect(
          (detailedResult['aiInsights']['recommendations'] as List).length,
          greaterThan((minimalResult['aiInsights']['recommendations'] as List).length),
        );
      });

      test('should handle COPPA compliance in fallback analysis', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        // Act - Simulate minor user
        final result = await service.performFallbackAnalysis(
          journalEntry,
          userContext: {'ageGroup': 'child', 'isMinor': true},
        );
        
        // Assert
        expect(result['coppaCompliant'], isTrue);
        expect(result['parentalConsentRequired'], isTrue);
        
        // Verify age-appropriate language
        final feedback = result['aiInsights']['feedback'];
        expect(feedback['language'], equals('age-appropriate'));
      });
    });

    group('Error Handling', () {
      test('should handle malformed webhook response', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Invalid JSON Response',
          200,
        ));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(journalEntry);
        
        // Assert
        expect(result['status'], equals('fallback'));
        expect(result['error'], contains('Invalid response format'));
      });

      test('should handle webhook authentication errors', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'error': 'Unauthorized'}),
          401,
        ));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(journalEntry);
        
        // Assert
        expect(result['status'], equals('fallback'));
        expect(result['error'], contains('Authentication'));
        
        // Should not retry on auth errors
        verify(mockHttpClient.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
            .called(1);
      });

      test('should handle rate limiting gracefully', () async {
        // Arrange
        final journalEntry = _createTestJournalEntry();
        
        when(mockHttpClient.post(
          Uri.parse(webhookUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'error': 'Rate limit exceeded', 'retryAfter': 60}),
          429,
        ));

        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
        when(mockPrefs.getStringList(any)).thenReturn([]);
        when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
        
        // Act
        final result = await service.sendToWebhook(journalEntry);
        
        // Assert
        expect(result['status'], equals('fallback'));
        expect(result['rateLimited'], isTrue);
        expect(result['retryAfter'], equals(60));
        
        // Should queue for later retry
        verify(mockPrefs.setStringList(
          'n8n_retry_queue',
          argThat(isNotEmpty),
        )).called(greaterThanOrEqualTo(1));
      });
    });
  });
}

// Helper functions
JournalEntry _createTestJournalEntry({
  String? id,
  String title = 'Test Entry',
  String description = 'Test journal entry description',
  String category = 'daily_care',
  List<String> aetSkills = const ['Animal Care'],
  int duration = 30,
}) {
  return JournalEntry(
    id: id ?? 'test_entry_${DateTime.now().millisecondsSinceEpoch}',
    userId: 'test_user_123',
    title: title,
    description: description,
    date: DateTime.now(),
    duration: duration,
    category: category,
    aetSkills: aetSkills,
    animalId: 'test_animal_123',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Map<String, dynamic> _createSuccessfulWebhookResponse() {
  return {
    'data': {
      'requestId': 'webhook_test_123',
      'status': 'completed',
      'qualityScore': 8,
      'competencyLevel': 'Proficient',
      'ffaStandards': ['AS.07.01', 'AS.07.02'],
      'aetSkills': ['Animal Health Management', 'Record Keeping'],
      'educationalConcepts': ['Animal Health', 'Veterinary Science'],
      'aiInsights': {
        'qualityAssessment': {
          'score': 8,
          'justification': 'Detailed and comprehensive entry',
        },
        'feedback': {
          'strengths': ['Thorough documentation', 'Good observation skills'],
          'improvements': ['Add specific measurements'],
        },
        'recommendations': [
          'Continue daily health monitoring',
          'Consider adding weight measurements',
        ],
        'careerConnections': ['Veterinarian', 'Animal Scientist'],
      },
      'processingTime': 1250,
      'timestamp': DateTime.now().toIso8601String(),
    },
  };
}